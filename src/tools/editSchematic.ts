import * as z from "zod/v4";

/** Matches schematic_edit.pas SchEditTryParsePowerPortStyle (TPowerObjectStyle). */
export const powerPortStyleSchema = z.enum([
  "circle",
  "arrow",
  "bar",
  "wave",
  "gnd_power",
  "power_ground",
  "gnd_signal",
  "signal_ground",
  "gnd_earth",
  "earth",
]);

const editSchematicActionEnum = z.enum([
  "set_component_transform",
  "set_component_parameters",
  "place_component",
  "add_text",
  "add_net_label",
  "add_wire",
  /** Phase 1 WIRES: alias of add_wire (same bridge + Pascal path). */
  "place_wire",
  /** Phase 1 WIRES: alias of add_net_label. */
  "place_net_label",
  /** Phase 1 WIRES: orthogonal bus polyline (same CSV format as add_wire). */
  "add_bus",
  /** Phase 1 WIRES: single bus entry segment; wire_points_csv must be exactly four numbers. */
  "add_bus_entry",
  /** Phase 2 POWER PORT: explicit style + optional net name / visibility. */
  "place_power_port",
  /** Phase 2: shortcut — default style gnd_power (override with power_port_style). */
  "place_gnd",
  /** Phase 2: shortcut — default style arrow (override with power_port_style). */
  "place_vcc",
]);

export const editSchematicInputSchema = z
  .object({
    action: editSchematicActionEnum,
    schematic_full_path: z.string().optional(),
    project_full_path: z.string().optional(),
    schematic_sheet_file_name: z.string().optional(),
    designator: z.string().optional(),
    x_mils: z.number().optional(),
    y_mils: z.number().optional(),
    rotation_deg: z.number().optional(),
    lib_reference: z.string().optional(),
    sch_library_path: z.string().optional(),
    parameter_names: z.array(z.string()).optional(),
    parameter_values: z.array(z.string()).optional(),
    text: z.string().optional(),
    net_name: z.string().optional(),
    wire_points_csv: z.string().optional(),
    power_port_style: powerPortStyleSchema.optional(),
    show_net_name: z.boolean().optional(),
  })
  .superRefine((val, ctx) => {
    const hasSheet =
      (val.schematic_full_path != null && val.schematic_full_path.length > 0) ||
      (val.schematic_sheet_file_name != null && val.schematic_sheet_file_name.length > 0);
    if (!hasSheet) {
      ctx.addIssue({
        code: "custom",
        message:
          "Provide schematic_full_path or schematic_sheet_file_name to identify the .SchDoc.",
        path: ["schematic_full_path"],
      });
    }

    switch (val.action) {
      case "set_component_transform": {
        if (val.designator == null || val.designator === "") {
          ctx.addIssue({
            code: "custom",
            message: "designator is required.",
            path: ["designator"],
          });
        }
        if (
          val.x_mils === undefined &&
          val.y_mils === undefined &&
          val.rotation_deg === undefined
        ) {
          ctx.addIssue({
            code: "custom",
            message: "Provide at least one of x_mils, y_mils, rotation_deg.",
            path: ["x_mils"],
          });
        }
        break;
      }
      case "set_component_parameters": {
        if (val.designator == null || val.designator === "") {
          ctx.addIssue({
            code: "custom",
            message: "designator is required.",
            path: ["designator"],
          });
        }
        const n = val.parameter_names;
        const v = val.parameter_values;
        if (n == null || v == null || n.length === 0) {
          ctx.addIssue({
            code: "custom",
            message:
              "parameter_names and parameter_values (non-empty, same length) are required.",
            path: ["parameter_names"],
          });
        } else if (n.length !== v.length) {
          ctx.addIssue({
            code: "custom",
            message: "parameter_names and parameter_values must have the same length.",
            path: ["parameter_values"],
          });
        }
        break;
      }
      case "place_component": {
        if (val.lib_reference == null || val.lib_reference === "") {
          ctx.addIssue({
            code: "custom",
            message: "lib_reference is required.",
            path: ["lib_reference"],
          });
        }
        if (val.designator == null || val.designator === "") {
          ctx.addIssue({
            code: "custom",
            message: "designator is required.",
            path: ["designator"],
          });
        }
        if (val.x_mils === undefined || val.y_mils === undefined) {
          ctx.addIssue({
            code: "custom",
            message: "x_mils and y_mils are required for place_component.",
            path: ["x_mils"],
          });
        }
        break;
      }
      case "add_text": {
        if (val.text == null || val.text === "") {
          ctx.addIssue({ code: "custom", message: "text is required.", path: ["text"] });
        }
        if (val.x_mils === undefined || val.y_mils === undefined) {
          ctx.addIssue({
            code: "custom",
            message: "x_mils and y_mils are required.",
            path: ["x_mils"],
          });
        }
        break;
      }
      case "add_net_label":
      case "place_net_label": {
        if (val.net_name == null || val.net_name === "") {
          ctx.addIssue({
            code: "custom",
            message: "net_name is required.",
            path: ["net_name"],
          });
        }
        if (val.x_mils === undefined || val.y_mils === undefined) {
          ctx.addIssue({
            code: "custom",
            message: "x_mils and y_mils are required.",
            path: ["x_mils"],
          });
        }
        break;
      }
      case "add_wire":
      case "place_wire": {
        if (val.wire_points_csv == null || val.wire_points_csv === "") {
          ctx.addIssue({
            code: "custom",
            message: "wire_points_csv is required.",
            path: ["wire_points_csv"],
          });
        }
        break;
      }
      case "add_bus": {
        if (val.wire_points_csv == null || val.wire_points_csv === "") {
          ctx.addIssue({
            code: "custom",
            message: "wire_points_csv is required for add_bus (same format as add_wire).",
            path: ["wire_points_csv"],
          });
        }
        break;
      }
      case "add_bus_entry": {
        const csv = val.wire_points_csv?.trim() ?? "";
        if (csv === "") {
          ctx.addIssue({
            code: "custom",
            message:
              "wire_points_csv is required for add_bus_entry: exactly four numbers x1,y1,x2,y2 (mils) for one segment.",
            path: ["wire_points_csv"],
          });
          break;
        }
        const parts = csv.split(",").map((p) => p.trim()).filter((p) => p.length > 0);
        if (parts.length !== 4) {
          ctx.addIssue({
            code: "custom",
            message:
              "add_bus_entry: wire_points_csv must contain exactly four comma-separated numbers (x1,y1,x2,y2 in mils).",
            path: ["wire_points_csv"],
          });
          break;
        }
        for (let i = 0; i < 4; i++) {
          const n = Number(parts[i]);
          if (!Number.isFinite(n)) {
            ctx.addIssue({
              code: "custom",
              message: `add_bus_entry: value at position ${i + 1} is not a finite number: ${parts[i]}`,
              path: ["wire_points_csv"],
            });
            break;
          }
        }
        break;
      }
      case "place_power_port": {
        if (val.power_port_style == null) {
          ctx.addIssue({
            code: "custom",
            message: "power_port_style is required for place_power_port.",
            path: ["power_port_style"],
          });
        }
        if (val.x_mils === undefined || val.y_mils === undefined) {
          ctx.addIssue({
            code: "custom",
            message: "x_mils and y_mils are required.",
            path: ["x_mils"],
          });
        }
        break;
      }
      case "place_gnd":
      case "place_vcc": {
        if (val.x_mils === undefined || val.y_mils === undefined) {
          ctx.addIssue({
            code: "custom",
            message: "x_mils and y_mils are required.",
            path: ["x_mils"],
          });
        }
        break;
      }
      default:
        break;
    }
  });

export type EditSchematicInput = z.infer<typeof editSchematicInputSchema>;
