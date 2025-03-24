import 'cheerio';

declare module 'cheerio' {
  interface CheerioOptions {
    withStartIndices?: boolean;
    withEndIndices?: boolean;
  }

  interface Element {
    startIndex?: number;
    endIndex?: number;
  }
}
