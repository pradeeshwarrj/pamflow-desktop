/**
 * All on-screen text lives in JSON files in this folder (en.json = English).
 * Screens never contain text directly; they call t('section.key').
 *
 *   t('project.title')                 -> "Set up your project"
 *   t('detect.ofFiles', { n: 63 })     -> "of 63 files"
 *
 * To add a language: copy en.json to e.g. es.json, translate the values
 * (keep the keys and the {placeholders}), and add it to `dictionaries`.
 */
import en from './en.json';

type Dict = { [key: string]: string | Dict };

const dictionaries: Record<string, Dict> = { en };

let language = 'en';

export function setLanguage(code: string): void {
  if (code in dictionaries) language = code;
}

export function t(key: string, vars?: Record<string, string | number>): string {
  const value = key
    .split('.')
    .reduce<string | Dict | undefined>(
      (node, part) => (node && typeof node === 'object' ? node[part] : undefined),
      dictionaries[language]
    );
  // A missing key shows the key itself, so it is easy to spot on screen.
  if (typeof value !== 'string') return key;
  if (!vars) return value;
  return value.replace(/\{(\w+)\}/g, (match, name) =>
    name in vars ? String(vars[name]) : match
  );
}
