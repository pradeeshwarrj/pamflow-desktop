/**
 * BirdNET names species as "Scientific name_Common name".
 * Split one into its two parts (either part may be missing).
 */
export function splitSpecies(label: string): { common: string; scientific: string } {
  const i = label.indexOf('_');
  if (i < 0) return { common: label, scientific: '' };
  return { scientific: label.slice(0, i), common: label.slice(i + 1) };
}
