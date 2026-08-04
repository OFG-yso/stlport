# STLport (Luanti STL Exporter)

[![License](https://img.shields.io/badge/license-LGPLv3.0%2B-blue.svg)](https://www.gnu.org/licenses/lgpl-3.0.en.html)


STLport is a mod which allows easy exporting of scenes from Luanti (Minetest)
to `.stl` files. These models can be imported directly into Blender, a
slicer, or another 3D program for rendering, animation, or 3D printing.

This mod is still in the beta phase; certain texturing features and node
drawtypes are not yet supported.

STLport is developed by OFG. It is a fork of
[Meshport](https://github.com/random-geek/meshport) by random-geek, adapted
to export STL instead of OBJ, produce watertight (closed) meshes suitable
for 3D printing, and orient models to the Z-up convention used by most
3D-printing and CAD tools. Many thanks to random-geek for the original
Meshport mod, whose mesh-generation code STLport is built upon — see
[Credits](#credits) below.

## Usage

Only players with the `stlport` privilege are allowed to select areas and
export meshes. This privilege is granted to singleplayer/admin players by
default.

To export a mesh, first select the area you want to export. There are two ways
to do this:

- Use the **STLport Area Selector** tool. Left- or right-click on a node or
  object to select either corner of the area. Hold sneak while clicking a node
  to select the node in front of the face you clicked on.
- Or, use the `/stl1` and `/stl2` commands to set either corner. You can
  specify a position (e.g. `/stl1 -24 0 24`) or leave the argument blank to
  use your current position (e.g. `/stl1`).

After selecting an area, use `/stlport [filename]` to export the mesh
(filename is optional).

The `/meshrst` command can be used to clear the current
selection.

Each export is saved directly as a single `.stl` file (named
`<player>_<filename>.stl`) in the `stlport` folder of the world directory. If
a file with that name already exists, ` (2)`, ` (3)`, etc. is appended to the
name.

### Importing into Blender

Once the model is exported, you can import the `.stl` file into Blender with
default settings. Note that STL files do not contain material or texture
information, so the imported model will be untextured.

Because most 3D-printing and CAD tools use a Z-up coordinate system while
Luanti is Y-up, the exported STL swaps the Y and Z axes relative to the raw
in-game coordinates.

To make the exported model watertight (suitable for 3D printing), any face on
the outer boundary of the selected area is always closed off, even if it
borders solid terrain just outside the selection (e.g. the ground under a
house). This only applies to cubic-style nodes (`normal`, `liquid`,
`allfaces`, `glasslike`, and the base of `plantlike_rooted`); node shapes
(`nodebox`) are already closed on their own.

#### Other fixes

Some mesh nodes may not have any vertex normals, which can lead to lighting
problems in Blender. This can usually be fixed by selecting the problematic
nodes (either manually or by selecting by material in edit mode), marking the
selected edges as sharp, and averaging the normals by face area. (Note that
STL files do not store normals from the source mesh — Blender, slicers, and
most other tools recompute them from the closed geometry on import.)

Some animated textures may also appear incorrect in Blender if you re-export
with materials. STLport tries to scale texture coordinates of animated
textures to fit within one frame, but some nodes (especially flowing liquids)
can exceed this boundary. If this is an issue, switch to a non-animated
texture and scale up the affected UV maps to match the new texture.

## Supported features

The following node drawtypes are currently supported:

- Cubic drawtypes, including `normal`, `allfaces`, `glasslike`, and their
  variants (see below)
- `glasslike_framed`
- `liquid` and `flowingliquid`
- `nodebox`
- `mesh` (only `.obj` meshes are read as input)
- `plantlike` and `plantlike_rooted`

STLport also supports many of Luanti's relevant features, including:

- Most `paramtype2`s (note that color is ignored for colored types)
- `visual_scale`
- World-aligned textures
- Animated textures (only one frame is used)

Some special rendering features are unsupported, including texture modifiers,
overlay textures, and node coloring. STL itself does not carry texture,
material, or color information at all, so all of the above will only be
visible if you re-export the underlying mesh data (e.g. via Blender) in a
format that supports it.

### Notes on cubic nodes

Drawtypes `allfaces_optional` and `glasslike_framed_optional` are output the
same as `allfaces` and `glasslike`, respectively.

Due to the differences between Luanti's rendering engine and 3D programs such
as Blender, it is impossible to exactly replicate how certain cubic nodes are
rendered in Luanti. Instead, STLport aims for a compromise between accuracy
and simplicity of geometry. In certain cases where two cubic nodes are
touching, one face may be offset slightly to avoid duplicate faces while still
allowing both faces to be visible.

## Credits

- **OFG** — STLport (STL export, closed/watertight meshes, axis conversion)
- **[random-geek](https://github.com/random-geek)** — original author of
  [Meshport](https://github.com/random-geek/meshport), the OBJ exporter that
  STLport is forked from and whose mesh-generation code this mod continues to
  rely on. Sincere thanks for the excellent original work.

## License

Textures are licensed under [CC BY 4.0][1]. Everything else (including source code)
is licensed under the GNU LGPL v3.0.

[1]: https://creativecommons.org/licenses/by/4.0/
