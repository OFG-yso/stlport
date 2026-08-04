--[[
	Copyright (C) 2021 random-geek (https://github.com/random-geek)

	This file is part of stlport.

	stlport is free software: you can redistribute it and/or modify it under
	the terms of the GNU Lesser General Public License as published by the Free
	Software Foundation, either version 3 of the License, or (at your option)
	any later version.

	stlport is distributed in the hope that it will be useful, but WITHOUT ANY
	WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
	FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for
	more details.

	You should have received a copy of the GNU Lesser General Public License
	along with stlport. If not, see <https://www.gnu.org/licenses/>.
]]

local S = stlport.S

--[[
	A buffer of faces.

	Faces are expected to be in this format:
	{
		verts = table,              -- list of vertices (as vectors)
		vert_norms = table,         -- list of vertex normals (as vectors)
		tex_coords = table,         -- list of texture coordinates, e.g. {x = 0.5, y = 1}
		tile_idx = int,             -- index of tile to use
		use_special_tiles = bool,   -- if true, use tiles from special_tiles field of nodedef
		texture = string,           -- name of actual texture to use)
	}

	Note to self/contributors--to avoid weird bugs, please follow these rules
	regarding table fields:

	1. Each table of vertices, vertex normals, or texture coordinates should be
	   unique to its parent face. That is, multiple faces or Faces objects
	   should not share references to the same table.
	2. Values within these tables are allowed to be duplicated. For example, one
	   face can reference the same vertex normal four times, and other faces or
	   Faces objects can also reference the same vertex normal.
]]
stlport.Faces = {}

function stlport.Faces:new()
	local o = { -- TODO: Separate tables for vertices/indices.
		faces = {},
	}

	self.__index = self
	setmetatable(o, self)
	return o
end

function stlport.Faces:insert_face(face)
	table.insert(self.faces, face)
end

function stlport.Faces:insert_all(faces)
	for _, face in ipairs(faces.faces) do
		table.insert(self.faces, face)
	end
end

function stlport.Faces:copy()
	local newFaces = stlport.Faces:new()
	newFaces.faces = table.copy(self.faces)
	return newFaces
end

function stlport.Faces:translate(vec)
	if vec.x == 0 and vec.y == 0 and vec.z == 0 then
		return
	end

	for _, face in ipairs(self.faces) do
		for i, vert in ipairs(face.verts) do
			face.verts[i] = vector.add(vert, vec)
		end
	end
end

function stlport.Faces:scale(scale)
	if scale == 1 then
		return
	end

	for _, face in ipairs(self.faces) do
		for i, vert in ipairs(face.verts) do
			face.verts[i] = vector.multiply(vert, scale)
		end
	end
end

function stlport.Faces:rotate_by_facedir(facedir)
	if facedir == 0 then
		return
	end

	for _, face in ipairs(self.faces) do
		for i, vert in ipairs(face.verts) do
			face.verts[i] = stlport.rotate_vector_by_facedir(vert, facedir)
		end

		for i, norm in ipairs(face.vert_norms) do
			face.vert_norms[i] = stlport.rotate_vector_by_facedir(norm, facedir)
		end
	end
end

function stlport.Faces:rotate_xz_degrees(degrees)
	if degrees == 0 then
		return
	end

	local rad = math.rad(degrees)
	local sinRad = math.sin(rad)
	local cosRad = math.cos(rad)

	for _, face in ipairs(self.faces) do
		for i, vert in ipairs(face.verts) do
			face.verts[i] = vector.new(
				vert.x * cosRad - vert.z * sinRad,
				vert.y,
				vert.x * sinRad + vert.z * cosRad
			)
		end

		for i, norm in ipairs(face.vert_norms) do
			face.vert_norms[i] = vector.new(
				norm.x * cosRad - norm.z * sinRad,
				norm.y,
				norm.x * sinRad + norm.z * cosRad
			)
		end
	end
end

function stlport.Faces:apply_tiles(nodeDef)
	for _, face in ipairs(self.faces) do
		local tiles
		if face.use_special_tiles then
			tiles = nodeDef.special_tiles
		else
			tiles = nodeDef.tiles
		end

		local tile = stlport.get_tile(tiles, face.tile_idx)
		-- tile.image is deprecated but is still used sometimes
		face.texture = tile.name or tile.image or tile

		-- If an animated texture is used, scale texture coordinates so only the first image is used.
		local animation = tile.animation
		if type(animation) == "table" then
			local xScale, yScale = 1, 1

			if animation.type == "vertical_frames" then
				local texW, texH = stlport.get_texture_dimensions(face.texture)
				if texW and texH then
					xScale = (animation.aspect_w or 16) / texW
					yScale = (animation.aspect_h or 16) / texH
				end
			elseif animation.type == "sheet_2d" then
				xScale = 1 / (animation.frames_w or 1)
				yScale = 1 / (animation.frames_h or 1)
			end

			if xScale ~= 1 or yScale ~= 1 then
				for i, coord in ipairs(face.tex_coords) do
					face.tex_coords[i] = {x = coord.x * xScale, y = coord.y * yScale}
				end
			end
		end
	end
end


local function clean_vector(vec)
	-- Prevents an issue involving negative zero values, which are not handled properly by `string.format`.
	return vector.new(
		vec.x == 0 and 0 or vec.x,
		vec.y == 0 and 0 or vec.y,
		vec.z == 0 and 0 or vec.z
	)
end


local function bimap_find_or_insert(forward, reverse, item)
	local idx = reverse[item]
	if not idx then
		idx = #forward + 1
		forward[idx] = item
		reverse[item] = idx
	end
	return idx
end


-- Stores a mesh in a form which is easily convertible to an .OBJ file.
stlport.Mesh = {}

function stlport.Mesh:new()
	local o = {
		-- Using two tables for elements makes insert_face() significantly faster.
		-- verts[1] = "0 -1 0"
		-- verts_reverse["0 -1 0"] = 1
		-- etc...
		verts = {},
		verts_reverse = {},
		vert_norms = {},
		vert_norms_reverse = {},
		tex_coords = {},
		tex_coords_reverse = {},
		faces = {},
		-- Flat list of triangles for STL export: {normal = vec, v1 = vec, v2 = vec, v3 = vec}
		stl_facets = {},
	}

	setmetatable(o, self)
	self.__index = self
	return o
end

-- Computes an outward-facing facet normal for a triangle.
local function triangle_normal(v1, v2, v3)
	local e1 = vector.subtract(v2, v1)
	local e2 = vector.subtract(v3, v1)
	local n = vector.cross(e1, e2)

	if vector.equals(n, vector.new(0, 0, 0)) then
		return n
	end

	return vector.normalize(n)
end

-- Adds the triangulated version of a (already axis-swapped) polygon to the STL facet list.
--
-- Swapping the Y and Z axes (done in insert_face) mirrors the geometry, which
-- would otherwise flip the winding order and make normals point inward. To
-- compensate, each triangle's last two vertices are swapped back here, and
-- the normal is computed fresh from the corrected winding.
function stlport.Mesh:insert_stl_face(verts)
	if #verts < 3 then
		return
	end

	-- Fan triangulation; handles the triangles and quads produced by stlport.
	for i = 2, #verts - 1 do
		local v1, v2, v3 = verts[1], verts[i + 1], verts[i]

		table.insert(self.stl_facets, {
			normal = triangle_normal(v1, v2, v3),
			v1 = v1,
			v2 = v2,
			v3 = v3,
		})
	end
end

function stlport.Mesh:insert_face(face)
	local indices = {
		verts = {},
		vert_norms = {},
		tex_coords = {},
	}

	local elementStr, vec
	local stlVerts = {}

	-- Add vertices to mesh.
	for i, vert in ipairs(face.verts) do
		-- Invert Z axis to comply with Blender's coordinate system.
		vec = clean_vector(vector.new(vert.x, vert.y, -vert.z))
		elementStr = string.format("%f %f %f", vec.x, vec.y, vec.z)
		indices.verts[i] = bimap_find_or_insert(self.verts, self.verts_reverse, elementStr)

		-- STL: swap the Y and Z axes. Luanti is Y-up; most 3D-printing/CAD
		-- tools expect a Z-up model.
		stlVerts[i] = clean_vector(vector.new(vert.x, vert.z, vert.y))
	end

	-- Add texture coordinates (UV map).
	for i, texCoord in ipairs(face.tex_coords) do
		elementStr = string.format("%f %f", texCoord.x, texCoord.y)
		indices.tex_coords[i] = bimap_find_or_insert(self.tex_coords, self.tex_coords_reverse, elementStr)
	end

	-- Add vertex normals.
	for i, vertNorm in ipairs(face.vert_norms) do
		-- Invert Z axis to comply with Blender's coordinate system.
		vec = clean_vector(vector.new(vertNorm.x, vertNorm.y, -vertNorm.z))
		elementStr = string.format("%f %f %f", vec.x, vec.y, vec.z)
		indices.vert_norms[i] = bimap_find_or_insert(self.vert_norms, self.vert_norms_reverse, elementStr)
	end

	-- Add faces to mesh.
	if not self.faces[face.texture] then
		self.faces[face.texture] = {}
	end

	local vertStrs = {}

	for i = 1, #indices.verts do
		table.insert(vertStrs,
			table.concat({
				indices.verts[i],
				-- If there is a vertex normal but not a texture coordinate, insert a blank string here.
				indices.tex_coords[i] or (indices.vert_norms[i] and ""),
				indices.vert_norms[i],
			}, "/")
		)
	end

	table.insert(self.faces[face.texture], table.concat(vertStrs, " "))

	-- Also record this face for STL export.
	self:insert_stl_face(stlVerts)
end

function stlport.Mesh:insert_faces(faces)
	for _, face in ipairs(faces.faces) do
		self:insert_face(face)
	end
end

function stlport.Mesh:write_obj(path)
	local objFile = io.open(path .. "/model.obj", "w")

	objFile:write("# Created using stlport (https://github.com/random-geek/stlport).\n")
	objFile:write("mtllib materials.mtl\n")

	-- Write vertices.
	for _, vert in ipairs(self.verts) do
		objFile:write(string.format("v %s\n", vert))
	end

	-- Write texture coordinates.
	for _, texCoord in ipairs(self.tex_coords) do
		objFile:write(string.format("vt %s\n", texCoord))
	end

	-- Write vertex normals.
	for _, vertNorm in ipairs(self.vert_norms) do
		objFile:write(string.format("vn %s\n", vertNorm))
	end

	-- Write faces, sorted in order of material.
	for mat, faces in pairs(self.faces) do
		objFile:write(string.format("usemtl %s\n", mat))

		for _, face in ipairs(faces) do
			objFile:write(string.format("f %s\n", face))
		end
	end

	objFile:close()
end

-- Writes the mesh as an ASCII STL file. STL has no support for textures or
-- materials, so only triangulated geometry is written. `filePath` is the
-- full path (including filename and extension) of the file to write.
function stlport.Mesh:write_stl(filePath)
	local stlFile = io.open(filePath, "w")

	stlFile:write("solid stlport\n")

	for _, facet in ipairs(self.stl_facets) do
		stlFile:write(string.format("facet normal %f %f %f\n", facet.normal.x, facet.normal.y, facet.normal.z))
		stlFile:write("outer loop\n")
		stlFile:write(string.format("vertex %f %f %f\n", facet.v1.x, facet.v1.y, facet.v1.z))
		stlFile:write(string.format("vertex %f %f %f\n", facet.v2.x, facet.v2.y, facet.v2.z))
		stlFile:write(string.format("vertex %f %f %f\n", facet.v3.x, facet.v3.y, facet.v3.z))
		stlFile:write("endloop\n")
		stlFile:write("endfacet\n")
	end

	stlFile:write("endsolid stlport\n")
	stlFile:close()
end

function stlport.Mesh:write_mtl(path, playerName)
	local matFile = io.open(path .. "/materials.mtl", "w")

	matFile:write("# Created using stlport (https://github.com/random-geek/stlport).\n")

	-- Write material information.
	for mat, _ in pairs(self.faces) do
		matFile:write(string.format("\nnewmtl %s\n", mat))

		-- Attempt to get the base texture, ignoring texture modifiers.
		local texName = string.match(mat, "[%w%s%-_%.]+%.png") or mat

		if stlport.texture_paths[texName] then
			if texName ~= mat then
				stlport.log(playerName, "warning", S("Ignoring texture modifers in material \"@1\".", mat))
			end

			matFile:write(string.format("map_Kd %s\n", stlport.texture_paths[texName]))
		else
			stlport.log(playerName, "warning",
					S("Could not find texture \"@1\". Using a dummy material instead.", texName))
			matFile:write(string.format("Kd %f %f %f\n", math.random(), math.random(), math.random()))
		end
	end

	matFile:close()
end
