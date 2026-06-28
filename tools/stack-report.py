#!/usr/bin/env python3
"""Static stack-usage report for a bare-metal Ada/ESP32-S3 example.

Consumes the per-frame stack-usage files (obj/*.su) and call-graph files
(obj/*.ci) that GCC emits under -fstack-usage / -fcallgraph-info -- produced by
building with STACK_ANALYSIS=1 (see examples/common/bare/build_ada.sh).

Two analyses:
  1. Per-frame    -- biggest single frames, and every DYNAMIC/BOUNDED frame
                     (those defeat static bounding: a VLA or alloca whose size
                     is not a compile-time constant).
  2. Worst-case   -- the deepest stack-summed call chain from each entry root.
                     Ravenscar/Jorvik forbids recursion, so the call graph is a
                     DAG and the longest path is a true bound on the APPLICATION
                     code's contribution (the pinned runtime is prebuilt without
                     these flags, so its frames show as external/unknown -- the
                     runtime watermark, `x stack --run`, measures those).

Usage:  stack-report.py <example-obj-dir> [--top N] [--task-sizes name=bytes,...]
"""
import argparse
import glob
import os
import re
import sys

SU_RE = re.compile(r'^(.*?):(\d+):(\d+):(.*)\t(\d+)\t(.+)$')
NODE_RE = re.compile(r'node:\s*{\s*title:\s*"([^"]*)"\s*label:\s*"([^"]*)"')
EDGE_RE = re.compile(r'edge:\s*{\s*sourcename:\s*"([^"]*)"\s*targetname:\s*"([^"]*)"')
BYTES_RE = re.compile(r'(\d+)\s+bytes\s+\(([^)]*)\)')


def human(n):
    return f"{n:,}".replace(",", " ")


class Frame:
    __slots__ = ("name", "src", "bytes", "qual")

    def __init__(self, name, src, b, qual):
        self.name, self.src, self.bytes, self.qual = name, src, b, qual


def load_su(objdir):
    frames = []
    for su in sorted(glob.glob(os.path.join(objdir, "*.su"))):
        with open(su, encoding="utf-8", errors="replace") as f:
            for line in f:
                m = SU_RE.match(line.rstrip("\n"))
                if not m:
                    continue
                path, ln, col, label, b, qual = m.groups()
                frames.append(Frame(label.strip(),
                                    f"{os.path.basename(path)}:{ln}",
                                    int(b), qual.strip()))
    return frames


def load_ci(objdir):
    """Return (stack_of: name->bytes, label_of: name->str, edges: name->set)."""
    stack_of, label_of, edges = {}, {}, {}
    for ci in sorted(glob.glob(os.path.join(objdir, "*.ci"))):
        with open(ci, encoding="utf-8", errors="replace") as f:
            for line in f:
                mn = NODE_RE.search(line)
                if mn:
                    name, lbl = mn.groups()
                    pretty = lbl.split("\\n", 1)[0]
                    label_of.setdefault(name, pretty)
                    mb = BYTES_RE.search(lbl)
                    if mb:
                        b = int(mb.group(1))
                        # keep the largest seen (a node may recur across units)
                        if b >= stack_of.get(name, -1):
                            stack_of[name] = b
                    continue
                me = EDGE_RE.search(line)
                if me:
                    s, t = me.groups()
                    edges.setdefault(s, set()).add(t)
    return stack_of, label_of, edges


def worst_case(name, stack_of, edges, memo, stack_path):
    """Longest stack-summed path from `name`.

    Returns (total, chain, hit_unknown, recursive).  A back-edge (name already on
    the current DFS path) means RECURSION: the depth is unbounded, so we stop and
    flag it (Ravenscar/Jorvik forbids recursion, so this should never fire for
    correct task code -- when it does, static bounding does not apply)."""
    if name in stack_path:                       # back-edge -> recursion
        return (0, [], False, True)
    if name in memo:
        return memo[name]
    stack_path.add(name)
    own = stack_of.get(name, 0)
    unknown = name not in stack_of               # external / runtime leaf
    recursive = False
    best_total, best_chain = 0, []
    for callee in edges.get(name, ()):
        t, chain, u, r = worst_case(callee, stack_of, edges, memo, stack_path)
        unknown = unknown or u
        recursive = recursive or r
        if t > best_total:
            best_total, best_chain = t, chain
    stack_path.discard(name)
    result = (own + best_total, [name] + best_chain, unknown, recursive)
    memo[name] = result
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("objdir")
    ap.add_argument("--top", type=int, default=12)
    ap.add_argument("--task-sizes", default="")
    args = ap.parse_args()

    if not os.path.isdir(args.objdir):
        sys.exit(f"stack-report: no such dir {args.objdir}")
    su_files = glob.glob(os.path.join(args.objdir, "*.su"))
    if not su_files:
        sys.exit("stack-report: no *.su files -- build with STACK_ANALYSIS=1 first")

    sizes = {}
    for kv in (x for x in args.task_sizes.split(",") if x):
        k, _, v = kv.partition("=")
        try:
            sizes[k.strip()] = int(v, 0)
        except ValueError:
            pass

    frames = load_su(args.objdir)
    stack_of, label_of, edges = load_ci(args.objdir)

    # ---- 1. per-frame -------------------------------------------------------
    print("== Per-frame stack usage (application units) ==")
    print(f"   {len(frames)} frames; "
          f"total of all frames = {human(sum(f.bytes for f in frames))} B "
          "(NOT a depth -- see worst-case below)\n")
    print(f"   {'bytes':>8}  {'qualifier':<16} location / subprogram")
    for f in sorted(frames, key=lambda f: -f.bytes)[:args.top]:
        print(f"   {human(f.bytes):>8}  {f.qual:<16} {f.src}  {f.name}")

    dyn = [f for f in frames if f.qual != "static"]
    print()
    if dyn:
        print(f"   !! {len(dyn)} DYNAMIC/BOUNDED frame(s) -- static depth is NOT "
              "guaranteed for paths through these:")
        for f in sorted(dyn, key=lambda f: -f.bytes):
            print(f"      {human(f.bytes):>8}  {f.qual:<16} {f.src}  {f.name}")
    else:
        print("   All frames are STATIC (compile-time constant) -- good: "
              "worst-case below is a real bound.")

    # ---- 2. worst-case call chains -----------------------------------------
    targeted = {t for outs in edges.values() for t in outs}
    roots = sorted(n for n in stack_of if n not in targeted)
    if "_ada_main" in stack_of and "_ada_main" not in roots:
        roots.insert(0, "_ada_main")

    print("\n== Worst-case call-chain depth per entry root ==")
    print("   (application frames only; '+ext' = chain also calls the prebuilt "
          "runtime, whose\n    frames are not counted here -- use the runtime "
          "watermark for the true figure)\n")
    rows = []
    any_recursion = False
    for r in roots:
        total, chain, unknown, recursive = worst_case(r, stack_of, edges, {}, set())
        any_recursion = any_recursion or recursive
        rows.append((total, r, chain, unknown, recursive))
    shown = sorted(rows, key=lambda x: -x[0])
    # always keep recursive roots visible even if they'd fall past the cut
    keep = shown[:args.top] + [x for x in shown[args.top:] if x[4]]
    for total, r, chain, unknown, recursive in keep:
        name = label_of.get(r, r)
        tag = "  !!RECURSIVE" if recursive else (" +ext" if unknown else "")
        line = f"   {human(total):>8} B{tag:<13} {name}"
        if r in sizes:
            head = sizes[r] - total
            flag = "  OVER!" if head < 0 else ""
            line += f"   [stack {human(sizes[r])} B -> headroom {human(head)} B{flag}]"
        print(line)
        pretty = " -> ".join(label_of.get(c, c) for c in chain
                             if c in stack_of)
        if pretty:
            print(f"            {pretty}")
    if any_recursion:
        print("\n   !! RECURSION detected on a marked chain -- its figure is a "
              "LOWER bound, not a\n      guarantee.  Ravenscar/Jorvik forbids "
              "recursion in task code; size such a\n      stack by reasoning about "
              "the maximum depth, then verify with the watermark.")
    print()


if __name__ == "__main__":
    main()
