module Ladb::OpenCutList

  require 'csv'
  require_relative '../../model/attributes/material_attributes'

  class CutlistExportWorker

    EXPORT_OPTION_SOURCE_SUMMARY = 0
    EXPORT_OPTION_SOURCE_CUTLIST = 1
    EXPORT_OPTION_SOURCE_INSTANCES_LIST = 2

    EXPORT_OPTION_COL_SEP_TAB = 0
    EXPORT_OPTION_COL_SEP_COMMA = 1
    EXPORT_OPTION_COL_SEP_SEMICOLON = 2

    EXPORT_OPTION_ENCODING_UTF8 = 0
    EXPORT_OPTION_ENCODING_UTF16LE = 1
    EXPORT_OPTION_ENCODING_UTF16BE = 2

    def initialize(settings, cutlist)
      @format = settings['format']
      @source = settings['source']
      @col_sep = settings['col_sep']
      @encoding = settings['encoding']
      @hide_entity_names = settings['hide_entity_names']
      @hide_tags = settings['hide_tags']
      @hide_cutting_dimensions = settings['hide_cutting_dimensions']
      @hide_bbox_dimensions = settings['hide_bbox_dimensions']
      @hide_untyped_material_dimensions = settings['hide_untyped_material_dimensions']
      @hide_final_areas = settings['hide_final_areas']
      @hide_edges = settings['hide_edges']
      @hidden_group_ids = settings['hidden_group_ids']

      @cutlist = cutlist

    end

    # -----

    def run
      return {errors: ['default.error']} unless @cutlist

      # Ask for export file path
      export_path = UI.savepanel(Plugin.instance.get_i18n_string('tab.cutlist.export.title'), @cutlist.dir, File.basename(@cutlist.filename, '.skp') + '.' + @format)

      if export_path

        if @format == 'csv'
          response = run_csv(export_path)
        elsif @format == 'json'
          response = run_json(export_path)
        else
          return {errors: ['unknown.export.format']}
        end

      end

      response
    end

    def _sanitize_value_string(value)
      value.gsub(/^~ /, '') unless value.nil?
    end

    def _format_edge_value(material_name, std_dimension)
      if material_name
        return "#{material_name} (#{std_dimension})"
      end

      ''
    end


    def run_csv(export_path)

      response = {
        errors: [],
          export_path: ''
      }

      begin
        # Convert col_sep
        col_sep = case @col_sep.to_i
                  when EXPORT_OPTION_COL_SEP_COMMA
                    ','
                  when EXPORT_OPTION_COL_SEP_SEMICOLON
                    ';'
                  else
                    "\t"
                  end

        # Convert col_sep
        case @encoding.to_i
        when EXPORT_OPTION_ENCODING_UTF16LE
          bom = "\xFF\xFE".force_encoding('utf-16le')
          encoding = 'UTF-16LE'
        when EXPORT_OPTION_ENCODING_UTF16BE
          bom = "\xFE\xFF".force_encoding('utf-16be')
          encoding = 'UTF-16BE'
        else
          bom = "\xEF\xBB\xBF"
          encoding = 'UTF-8'
        end

        File.open(export_path, "wb+:#{encoding}") do |f|
          options = {col_sep: col_sep}
          csv_file = CSV.generate(**options) do |csv|

            case @source.to_i

            when EXPORT_OPTION_SOURCE_SUMMARY

              # Header row
              header = []
              header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.material_type'))
              header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.material_thickness'))
              header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.part_count'))
              header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.total_cutting_length'))
              header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.total_cutting_area'))
              header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.total_cutting_volume'))
              unless @hide_final_areas
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.total_final_area'))
              end

              csv << header

              @cutlist.groups.each do |group|
                next if @hidden_group_ids.include? group.id

                row = []
                row.push(Plugin.instance.get_i18n_string("tab.materials.type_#{group.material_type}"))
                row.push((group.material_name || Plugin.instance.get_i18n_string('tab.cutlist.material_undefined')) + (group.material_type > 0 ? ' / ' + group.std_dimension : ''))
                row.push(group.part_count)
                row.push(group.total_cutting_length.nil? ? '' : _sanitize_value_string(group.total_cutting_length))
                row.push(group.total_cutting_area.nil? ? '' : _sanitize_value_string(group.total_cutting_area))
                row.push(group.total_cutting_volume.nil? ? '' : _sanitize_value_string(group.total_cutting_volume))
                unless @hide_final_areas
                  row.push((group.total_final_area.nil? or group.invalid_final_area_part_count > 0) ? '' : _sanitize_value_string(group.total_final_area))
                end

                csv << row
              end

            when EXPORT_OPTION_SOURCE_CUTLIST

              # Header row
              header = []
              header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.number'))
              header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.name'))
              header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.count'))
              unless @hide_cutting_dimensions
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_length'))
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_width'))
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_thickness'))
              end
              unless @hide_bbox_dimensions
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_length'))
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_width'))
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_thickness'))
              end
              unless @hide_final_areas
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.final_area'))
              end
              header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.material_name'))
              unless @hide_entity_names
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.entity_names'))
              end
              unless @hide_tags
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.tags'))
              end
              unless @hide_edges
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_ymin'))
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_ymax'))
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_xmin'))
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_xmax'))
              end

              csv << header

              # Content rows
              @cutlist.groups.each do |group|
                next if @hidden_group_ids.include? group.id

                group.parts.each do |part|

                  no_cutting_dimensions = group.material_type == MaterialAttributes::TYPE_UNKNOWN
                  no_dimensions = group.material_type == MaterialAttributes::TYPE_UNKNOWN && @hide_untyped_material_dimensions

                  row = []
                  row.push(part.number)
                  row.push(part.name)
                  row.push(part.count)
                  unless @hide_cutting_dimensions
                    row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_length))
                    row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_width))
                    row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_thickness))
                  end
                  unless @hide_bbox_dimensions
                    row.push(no_dimensions ? '' : _sanitize_value_string(part.length))
                    row.push(no_dimensions ? '' : _sanitize_value_string(part.width))
                    row.push(no_dimensions ? '' : _sanitize_value_string(part.thickness))
                  end
                  unless @hide_final_areas
                    row.push(no_dimensions ? '' : _sanitize_value_string(part.final_area))
                  end
                  row.push(group.material_display_name)
                  unless @hide_entity_names
                    row.push(part.is_a?(Part) ? part.entity_names.map(&:first).join(',') : '')
                  end
                  unless @hide_tags
                    row.push(part.tags.empty? ? '' : part.tags.join(','))
                  end
                  unless @hide_edges
                    row.push(_format_edge_value(part.edge_material_names[:ymin], part.edge_std_dimensions[:ymin]))
                    row.push(_format_edge_value(part.edge_material_names[:ymax], part.edge_std_dimensions[:ymax]))
                    row.push(_format_edge_value(part.edge_material_names[:xmin], part.edge_std_dimensions[:xmin]))
                    row.push(_format_edge_value(part.edge_material_names[:xmax], part.edge_std_dimensions[:xmax]))
                  end

                  csv << row
                end
              end

            when EXPORT_OPTION_SOURCE_INSTANCES_LIST

              # Header row
              header = []
              header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.number'))
              header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.path'))
              header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.instance_name'))
              header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.definition_name'))
              unless @hide_cutting_dimensions
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_length'))
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_width'))
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_thickness'))
              end
              unless @hide_bbox_dimensions
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_length'))
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_width'))
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_thickness'))
              end
              unless @hide_final_areas
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.final_area'))
              end
              header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.material_name'))
              unless @hide_tags
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.tags'))
              end
              unless @hide_edges
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_ymax'))
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_ymin'))
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_xmin'))
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_xmax'))
              end

              csv << header

              # Content rows
              @cutlist.groups.each do |group|
                next if @hidden_group_ids.include? group.id
                next if group.material_type == MaterialAttributes::TYPE_EDGE # Edges don't have instances

                group.parts.each do |part|

                  no_cutting_dimensions = group.material_type == MaterialAttributes::TYPE_UNKNOWN
                  no_dimensions = group.material_type == MaterialAttributes::TYPE_UNKNOWN && @hide_untyped_material_dimensions

                  parts = part.is_a?(FolderPart) ? part.children : [part]
                  parts.each do |part|

                    # Ungroup parts
                    part.def.instance_infos.each do |serialized_path, instance_info|

                      # Compute path with entities names (from root group to final entity)
                      path_names = []
                      instance_info.path.each do |entity|
                        # Uses entityID if instance name is empty
                        path_names.push(entity.name.empty? ? "##{entity.entityID}" : entity.name)
                      end
                      # Pop the instance name to put it in a separated column
                      instance_name = path_names.pop

                      row = []
                      row.push(part.number)
                      row.push(path_names.join('/'))
                      row.push(instance_name)
                      row.push(part.name)
                      unless @hide_cutting_dimensions
                        row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_length))
                        row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_width))
                        row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_thickness))
                      end
                      unless @hide_bbox_dimensions
                        row.push(no_dimensions ? '' : _sanitize_value_string(part.length))
                        row.push(no_dimensions ? '' : _sanitize_value_string(part.width))
                        row.push(no_dimensions ? '' : _sanitize_value_string(part.thickness))
                      end
                      unless @hide_final_areas
                        row.push(no_dimensions ? '' : _sanitize_value_string(part.final_area))
                      end
                      row.push(group.material_display_name)
                      unless @hide_tags
                        row.push(part.tags.empty? ? '' : part.tags.join(','))
                      end
                      unless @hide_edges
                        row.push(_format_edge_value(part.edge_material_names[:ymax], part.edge_std_dimensions[:ymax]))
                        row.push(_format_edge_value(part.edge_material_names[:ymin], part.edge_std_dimensions[:ymin]))
                        row.push(_format_edge_value(part.edge_material_names[:xmin], part.edge_std_dimensions[:xmin]))
                        row.push(_format_edge_value(part.edge_material_names[:xmax], part.edge_std_dimensions[:xmax]))
                      end

                      csv << row

                    end

                  end

                end
              end

            end

          end

          # Write file
          f.write(bom)
          f.write(csv_file)

          # Populate response
          response[:export_path] = export_path.tr("\\", '/') # Standardize path by replacing \ by /

        end
      rescue => e
        puts e.message
        puts e.backtrace
        response[:errors] << ['tab.cutlist.error.failed_to_write_export_file', {error: e.message}]
      end
      response
    end

    def run_json(export_path)

      response = {
        errors: [],
          export_path: ''
      }

      begin

        File.open(export_path, "wb+:UTF-8") do |json_file|
          json_hash = {
            :filename => @cutlist.filename,
            :dir => @cutlist.dir.tr("\\", '/')
          }

          @cutlist.groups.each do |group|
            next if @hidden_group_ids.include? group.id

            material_type_str = case group.material_type
                                when MaterialAttributes::TYPE_DIMENSIONAL
                                  'dimensional_parts'
                                when MaterialAttributes::TYPE_SHEET_GOOD
                                  'sheet_goods'
                                when MaterialAttributes::TYPE_SOLID_WOOD
                                  'solid_woods'
                                when MaterialAttributes::TYPE_EDGE
                                  'edge_bindings'
                                else
                                  'undefined'
                                end

            group_row = {}
            group_row[:material_type] = material_type_str
            group_row[:material_thickness] = group.std_thickness
            group_row[:width] = group.std_dimension if group.material_type == MaterialAttributes::TYPE_EDGE
            group_row[:material] = group.material_name || '<undefined>'
            group_row[:part_count] = group.part_count
            group_row[:total_cutting_length] = group.total_cutting_length.nil? ? '' : _sanitize_value_string(group.total_cutting_length)
            group_row[:total_cutting_area] = group.total_cutting_area.nil? ? '' : _sanitize_value_string(group.total_cutting_area)
            group_row[:total_cutting_volume] = group.total_cutting_volume.nil? ? '' : _sanitize_value_string(group.total_cutting_volume)
            unless @hide_final_areas
              group_row[:total_final_area] = (group.total_final_area.nil? or group.invalid_final_area_part_count > 0) ? '' : _sanitize_value_string(group.total_final_area)
            end

            group.parts.each do |part|
              (group_row[:parts] ||= []) << part_to_json(part, group)
            end

            (json_hash[material_type_str] ||= []) << group_row
          end
          json_file.write(JSON.pretty_generate(json_hash))
          response[:export_path] = export_path.tr("\\", '/')
        end
      rescue => e
        puts e.message
        puts e.backtrace
        response[:errors] << ['tab.cutlist.error.failed_to_write_export_file', {error: e.message}]
      end

      response
    end

    def part_to_json(part, group)

      no_cutting_dimensions = group.material_type == MaterialAttributes::TYPE_UNKNOWN
      no_dimensions = group.material_type == MaterialAttributes::TYPE_UNKNOWN && @hide_untyped_material_dimensions

      part_row = {}
      part_row[:number] = part.number
      part_row[:name] = part.name
      part_row[:count] = part.count
      part_row[:flipped] = part.flipped
      if group.material_type != MaterialAttributes::TYPE_EDGE
        part_row[:instances] = []
        parts = part.is_a?(FolderPart) ? part.children : [part]
        parts.each do |part_instance|
          part_instance.def.instance_infos.each do |serialized_path, instance_info|
            path_names = []
            instance_info.path.each do |entity|
              path_names.push(entity.name.empty? ? "##{entity.entityID}" : entity.name)
            end
            instance_name = path_names.pop
            instance_row = {}
            instance_row[:name] = instance_name
            instance_row[:definition] = part_instance.name
            instance_row[:path] = path_names.join('/')
            part_row[:instances] << instance_row
          end
        end
      end

      unless @hide_cutting_dimensions
        part_row[:cutting_length] = no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_length)
        part_row[:cutting_width] = no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_width)
        part_row[:cutting_thickness] =no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_thickness)
      end
      unless @hide_bbox_dimensions
        part_row[:finish_length] = no_dimensions ? '' :  _sanitize_value_string(part.length)
        part_row[:finish_width] = no_dimensions ? '' : _sanitize_value_string(part.width)
        part_row[:finish_thickness] = no_dimensions ? '' : _sanitize_value_string(part.thickness)
      end
      unless @hide_final_areas
        part_row[:final_area] = no_dimensions ? '' : _sanitize_value_string(part.final_area)
      end
      part_row[:material_name] = group.material_display_name
      unless @hide_entity_names
        part_row[:entity_names] = part.is_a?(Part) ? part.entity_names.map(&:first).join(',') : ''
      end
      unless @hide_tags
        part_row[:tags] = part.tags.join(',') unless part.tags.empty?
      end
      if !@hide_edges && group.material_type != MaterialAttributes::TYPE_EDGE
        edges = {}
        %i[ymin ymax xmin xmax].each do |edge|
          next unless part.edge_material_names[edge]
          edge_thickness, edge_width = part.edge_std_dimensions[edge].split(' x ')
          edges[edge] = {
            material: part.edge_material_names[edge],
              thickness: edge_thickness,
              width: edge_width
          }
        end
        part_row[:edges] = edges unless edges.empty?
      end

      if group.material_type == MaterialAttributes::TYPE_SHEET_GOOD
        part.surfaces_components.each do |surface_component|
          component_json = {
              name: surface_component.name,
              side: surface_component.side,
              x: surface_component.x,
              y: surface_component.y
          }
          (part_row[:surface_components] ||= []) << component_json
        end
      end

      part_row
    end
  end

end
