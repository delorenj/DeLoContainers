import { FormatObject } from "../controllers/v2/types";

/**
 * Checks if a format of a specific type exists in the formats array.
 * Returns the format object if found, undefined otherwise.
 *
 * This function handles both simple formats (e.g., { type: "markdown" })
 * and complex formats with additional properties (e.g., { type: "screenshot", fullPage: true }).
 *
 * @param formats - Array of format objects
 * @param type - The format type to search for
 * @returns The format object if found, undefined otherwise
 */
export function hasFormatOfType<T extends FormatObject["type"]>(
  formats: FormatObject[] | undefined,
  type: T,
): Extract<FormatObject, { type: T }> | undefined {
  if (!formats) {
    return undefined;
  }

  const found = formats.find(f => f.type === type);
  return found as Extract<FormatObject, { type: T }> | undefined;
}

/**
 * Checks if any of the specified format types exist in the formats array.
 * Returns true if at least one of the types is found.
 *
 * @param formats - Array of format objects
 * @param types - Array of format types to search for
 * @returns true if any of the types are found, false otherwise
 */
export function hasAnyFormatOfTypes(
  formats: FormatObject[] | undefined,
  types: FormatObject["type"][],
): boolean {
  if (!formats) {
    return false;
  }

  return formats.some(f => types.includes(f.type));
}
