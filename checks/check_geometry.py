#!/usr/bin/env python3
"""Check Vigil-Arm meshes against the documented envelopes and passages.

The usual entry point is ../scripts/check.sh, which re-exports every STL and
passes that directory here. Running this file directly checks the committed
STLs against the documented dimensions and leaves the re-export comparison out.

  python3 checks/check_geometry.py
  python3 checks/check_geometry.py --exported-dir /path/to/fresh/stls
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import trimesh

REPO = Path(__file__).resolve().parents[1]
AXIS_INDEX = {"x": 0, "y": 1, "z": 2}


def load_config(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def load_mesh(path: Path) -> trimesh.Trimesh:
    loaded = trimesh.load(path, force="mesh", process=True)
    if not isinstance(loaded, trimesh.Trimesh):
        raise RuntimeError(f"{path} did not load as a single mesh")
    return loaded


def passage_for(config: dict, model: dict) -> dict:
    passage = {}
    preset = model.get("passage_preset")
    if preset:
        passage.update(config["passage_presets"][preset])
    passage.update(model.get("passage", {}))
    return passage


def plane_point(axis: str, station: float, center: np.ndarray, offset: np.ndarray) -> np.ndarray:
    """Place a point. `center` and `offset` are coordinates in the plane normal to `axis`."""
    point = np.zeros(3, dtype=np.float64)
    point[AXIS_INDEX[axis]] = station
    if axis == "z":
        point[0] = center[0] + offset[0]
        point[1] = center[1] + offset[1]
    elif axis == "x":
        point[1] = center[0] + offset[0]
        point[2] = center[1] + offset[1]
    elif axis == "y":
        point[0] = center[0] + offset[0]
        point[2] = center[1] + offset[1]
    else:
        raise ValueError(f"unsupported axis {axis}")
    return point


def ray_counts(mesh: trimesh.Trimesh, origins: np.ndarray, direction: np.ndarray) -> np.ndarray:
    """Count triangle hits of each ray. A clear through-passage is a count of zero."""
    origins = np.asarray(origins, dtype=np.float64)
    direction = np.asarray(direction, dtype=np.float64)
    direction = direction / np.linalg.norm(direction)
    triangles = np.asarray(mesh.triangles, dtype=np.float64)
    if len(origins) == 0 or len(triangles) == 0:
        return np.zeros(len(origins), dtype=np.int32)

    vertex0 = triangles[:, 0]
    edge1 = triangles[:, 1] - vertex0
    edge2 = triangles[:, 2] - vertex0
    pvec = np.cross(direction, edge2)
    det = np.einsum("fj,fj->f", pvec, edge1)
    valid = np.abs(det) > 1e-12
    inv_det = np.zeros_like(det)
    inv_det[valid] = 1.0 / det[valid]

    counts = np.zeros(len(origins), dtype=np.int32)
    with np.errstate(divide="ignore", invalid="ignore"):
        for start in range(0, len(origins), 32):
            batch = origins[start : start + 32]
            offset = batch[:, None, :] - vertex0
            u = np.einsum("rfj,fj->rf", offset, pvec) * inv_det
            qvec = np.cross(offset, edge1)
            v = np.einsum("rfj,j->rf", qvec, direction) * inv_det
            distance = np.einsum("rfj,fj->rf", qvec, edge2) * inv_det
            hit = valid & (u >= 0.0) & (v >= 0.0) & (u + v <= 1.0) & (distance > 1e-8)
            counts[start : start + len(batch)] = hit.sum(axis=1)
    return counts


def inside_solid(mesh: trimesh.Trimesh, points: np.ndarray) -> np.ndarray:
    """Odd crossing count along +Z means the point is in the solid."""
    direction = np.array([0.0, 0.0, 1.0])
    return ray_counts(mesh, points, direction) % 2 == 1


def through_rays(mesh: trimesh.Trimesh, passage: dict) -> tuple[np.ndarray, np.ndarray, int]:
    axis = passage["axis"]
    center = np.asarray(passage["center_mm"], dtype=np.float64)
    rect = np.asarray(passage["through_rect_mm"], dtype=np.float64)
    grid = [int(value) for value in passage["through_grid"]]
    inset = float(passage.get("inset_mm", 0.0))
    half = rect / 2.0 - inset
    if np.any(half <= 0):
        raise ValueError("passage inset is larger than the test rectangle")
    primary = np.linspace(-half[0], half[0], grid[0])
    secondary = np.linspace(-half[1], half[1], grid[1])
    axis_index = AXIS_INDEX[axis]
    start = float(mesh.bounds[0, axis_index] - 1.0)
    direction = np.zeros(3, dtype=np.float64)
    direction[axis_index] = 1.0
    origins = [
        plane_point(axis, start, center, np.array([along, across], dtype=np.float64))
        for across in secondary
        for along in primary
    ]
    return np.vstack(origins), direction, grid[0] * grid[1]


def directed_hausdorff(source: np.ndarray, target: np.ndarray) -> float:
    worst = 0.0
    for start in range(0, len(source), 256):
        block = source[start : start + 256]
        distance = np.linalg.norm(block[:, None, :] - target[None, :, :], axis=2)
        worst = max(worst, float(distance.min(axis=1).max()))
    return worst


def nonmanifold_edges(mesh: trimesh.Trimesh) -> int:
    _edges, counts = np.unique(mesh.edges_sorted, axis=0, return_counts=True)
    return int(np.sum(counts != 2))


def fmt_vec(values: np.ndarray) -> str:
    return "×".join(f"{value:.3f}" for value in values)


def check_model(config: dict, model: dict, repo: Path, exported_dir: Path | None) -> list[str]:
    errors: list[str] = []
    model_id = model["id"]
    committed_path = repo / model["stl"]
    spec_path = committed_path
    if exported_dir is not None:
        spec_path = exported_dir / model["stl"]
        if not spec_path.is_file():
            return [f"{model_id}: re-exported STL is missing at {spec_path}"]
    if not committed_path.is_file():
        return [f"{model_id}: committed STL is missing at {committed_path}"]

    mesh = load_mesh(spec_path)
    tolerances = config["tolerances"]
    extents = np.asarray(mesh.extents, dtype=np.float64)
    expected_extents = np.asarray(model["extents_mm"], dtype=np.float64)
    extent_error = float(np.max(np.abs(extents - expected_extents)))
    if extent_error > tolerances["documented_extents_mm"]:
        errors.append(
            f"{model_id}: extents {fmt_vec(extents)} mm differ from documented "
            f"{fmt_vec(expected_extents)} mm by {extent_error:.3f} mm "
            f"(limit {tolerances['documented_extents_mm']} mm; {model['extents_source']})"
        )

    if not mesh.is_watertight:
        errors.append(
            f"{model_id}: mesh is not watertight "
            f"({nonmanifold_edges(mesh)} edges are not shared by exactly two faces)"
        )
    if not mesh.is_winding_consistent:
        errors.append(f"{model_id}: face winding is inconsistent")
    if int(mesh.euler_number) != int(model["euler"]):
        errors.append(
            f"{model_id}: Euler characteristic is {int(mesh.euler_number)}, "
            f"expected {int(model['euler'])} for the documented passages"
        )

    passage = passage_for(config, model)
    pdf_center_z = model.get("pdf_center_z_mm")
    if pdf_center_z is not None and passage.get("axis") == "x":
        center_z = float(passage["center_mm"][1])
        if abs(center_z - float(pdf_center_z)) > 0.1:
            errors.append(
                f"{model_id}: configured slot center Z {center_z:.3f} mm is more than "
                f"0.1 mm from vigil.pdf page 6 ({pdf_center_z} mm)"
            )
    try:
        origins, direction, ray_count = through_rays(mesh, passage)
    except (KeyError, ValueError) as exc:
        errors.append(f"{model_id}: passage config is incomplete ({exc})")
        origins = None
    else:
        expected_count = passage.get("clear_ray_count")
        if expected_count is not None and ray_count != int(expected_count):
            errors.append(
                f"{model_id}: through-passage grid has {ray_count} rays, "
                f"expected {expected_count}"
            )
        counts = ray_counts(mesh, origins, direction)
        blocked = int(np.sum(counts > 0))
        if blocked:
            errors.append(
                f"{model_id}: {blocked} of {ray_count} rays through the documented "
                f"passage hit the mesh ({passage['source']})"
            )

        center = np.asarray(passage["center_mm"], dtype=np.float64)
        station = float(passage["station_mm"])
        solid = np.vstack([
            plane_point(passage["axis"], station, center, np.asarray(offset, dtype=np.float64))
            for offset in passage["solid_offsets_mm"]
        ])
        void = np.vstack([
            plane_point(passage["axis"], station, center, np.asarray(offset, dtype=np.float64))
            for offset in passage["void_offsets_mm"]
        ])
        solid_inside = inside_solid(mesh, solid)
        void_inside = inside_solid(mesh, void)
        if not np.all(solid_inside):
            missed = solid[~solid_inside]
            errors.append(
                f"{model_id}: material is missing just outside the documented opening "
                f"at {np.array2string(missed, precision=2)}"
            )
        if np.any(void_inside):
            blocked_points = void[void_inside]
            errors.append(
                f"{model_id}: the documented opening is solid "
                f"at {np.array2string(blocked_points, precision=2)}"
            )

    drift = ""
    if exported_dir is not None:
        committed = load_mesh(committed_path)
        bbox_error = float(np.max(np.abs(mesh.bounds - committed.bounds)))
        volume_scale = max(abs(float(committed.volume)), 1.0)
        volume_error = abs(float(mesh.volume) - float(committed.volume)) / volume_scale
        hausdorff = max(
            directed_hausdorff(mesh.vertices, committed.vertices),
            directed_hausdorff(committed.vertices, mesh.vertices),
        )
        if bbox_error > tolerances["reexport_bbox_mm"]:
            errors.append(
                f"{model_id}: re-export bounding box differs from the committed STL "
                f"by {bbox_error:.4f} mm (limit {tolerances['reexport_bbox_mm']} mm)"
            )
        if volume_error > tolerances["reexport_volume_rel"]:
            errors.append(
                f"{model_id}: re-export volume differs from the committed STL "
                f"by relative {volume_error:.3e} "
                f"(limit {tolerances['reexport_volume_rel']:.1e}; "
                f"export {mesh.volume:.2f} mm³, committed {committed.volume:.2f} mm³)"
            )
        if hausdorff > tolerances["reexport_vertex_hausdorff_mm"]:
            errors.append(
                f"{model_id}: re-export surface differs from the committed STL "
                f"by {hausdorff:.4f} mm (limit {tolerances['reexport_vertex_hausdorff_mm']} mm)"
            )
        drift = (
            f" drift bbox {bbox_error:.4f} mm, volume {volume_error:.3e}, "
            f"hausdorff {hausdorff:.4f} mm,"
        )

    status = "FAIL" if errors else "PASS"
    print(
        f"{status:4} {model_id:12} extents {fmt_vec(extents)} mm "
        f"watertight {bool(mesh.is_watertight)} euler {int(mesh.euler_number)}{drift} "
        f"faces {len(mesh.faces)}"
    )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=REPO)
    parser.add_argument("--config", type=Path, default=REPO / "checks" / "expected.json")
    parser.add_argument(
        "--exported-dir",
        type=Path,
        help="directory of freshly exported STLs, laid out like the repository",
    )
    args = parser.parse_args()
    config = load_config(args.config)
    repo = args.repo.resolve()
    exported = args.exported_dir.resolve() if args.exported_dir else None

    print(f"config {args.config}")
    if exported is None:
        print("checking committed STLs only; pass --exported-dir to compare a fresh export")
    else:
        print(f"checking re-export in {exported} against committed STLs and the documented envelopes")

    failures: list[str] = []
    for model in config["models"]:
        failures.extend(check_model(config, model, repo, exported))

    failed_ids = []
    for model in config["models"]:
        prefix = f"{model['id']}:"
        if any(item.startswith(prefix) for item in failures):
            failed_ids.append(model["id"])
    print(f"{len(config['models'])} models, {len(failed_ids)} failed")
    for item in failures:
        print(f"ERROR {item}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
