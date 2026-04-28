-- Patch while in commit 38a9f9e03c9ab7ccd6353788347c2e2fdf89a366

-- Problem:
-- When changing models during an active chat (e.g., switching from `gpt-4.1` to `gpt-5 mini`),
-- parameters that are unsupported by the new model (like `temperature` for `gpt-5 mini`)
-- are properly ignored when building new settings. However, the original `map_schema_to_params`
-- loop only iterates through *active* settings. It never clears the disabled properties from
-- the base parameters structure, resulting in API rejections.
--
-- Solution:
-- Monkey-patch `codecompanion.adapters.http.init.map_schema_to_params` to iterate through
-- the entire adapter `schema` rather than just the new `settings`. Any parameters missing
-- in the new `settings` will fallback to `nil`, effectively clearing out stale values.

return function()
  -- =======================================================================
  -- Patch for map_schema_to_params (adapters/http/init.lua)
  -- =======================================================================
  local http_adapter_ok, http_adapter = pcall(require, "codecompanion.adapters.http")
  if http_adapter_ok then
    http_adapter.map_schema_to_params = function(self, settings)
      settings = settings or self:make_from_schema()

      -- PATCH: Original vs New
      -- ORIGINAL: for k, v in pairs(settings) do
      -- NEW: Iterate over the full schema so that dropped keys become `nil` and get deleted
      for k, _ in pairs(self.schema) do
        local v = settings[k]
        local mapping = self.schema[k] and self.schema[k].mapping

        if mapping then
          -- Parse the mapping path
          local mapping_segments = {}
          for segment in string.gmatch(mapping, "[^.]+") do
            table.insert(mapping_segments, segment)
          end

          -- Navigate to the mapping location
          local current = self
          for i = 1, #mapping_segments do
            if not current[mapping_segments[i]] then
              current[mapping_segments[i]] = {}
            end
            current = current[mapping_segments[i]]
          end

          -- Parse the schema key for nested structure
          local key_segments = {}
          for segment in string.gmatch(k, "[^.]+") do
            table.insert(key_segments, segment)
          end

          -- Create nested structure based on the key segments
          for i = 1, #key_segments - 1 do
            if not current[key_segments[i]] then
              current[key_segments[i]] = {}
            end
            current = current[key_segments[i]]
          end

          -- Set the final value at the deepest level
          -- [PATCH] This naturally resolves to `nil` and unsets the field if disabled/missing!
          current[key_segments[#key_segments]] = v
        end
      end

      return self
    end
  end
end
