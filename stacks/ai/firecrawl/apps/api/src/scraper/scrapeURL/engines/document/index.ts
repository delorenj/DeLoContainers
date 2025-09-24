import { Meta } from "../..";
import { EngineScrapeResult } from "..";
import { fetchFileToBuffer } from "../utils/downloadFile";
import { DocumentConverter, DocumentType } from "@mendable/firecrawl-rs";

const converter = new DocumentConverter();

function getDocumentTypeFromUrl(url: string): DocumentType {
  const urlLower = url.toLowerCase();
  if (urlLower.endsWith(".docx")) return DocumentType.Docx;
  if (urlLower.endsWith(".odt")) return DocumentType.Odt;
  if (urlLower.endsWith(".rtf")) return DocumentType.Rtf;

  return DocumentType.Docx; // hope for the best
}

function getDocumentTypeFromContentType(
  contentType: string | null,
): DocumentType | null {
  if (!contentType) return null;

  const ct = contentType.toLowerCase();

  if (
    ct.includes(
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ) ||
    ct.includes("application/msword")
  ) {
    return DocumentType.Docx;
  }

  if (ct.includes("application/vnd.oasis.opendocument.text")) {
    return DocumentType.Odt;
  }

  if (ct.includes("application/rtf") || ct.includes("text/rtf")) {
    return DocumentType.Rtf;
  }

  return null;
}

export async function scrapeDocument(meta: Meta): Promise<EngineScrapeResult> {
  const { response, buffer } = await fetchFileToBuffer(
    meta.rewrittenUrl ?? meta.url,
    {
      headers: meta.options.headers,
      signal: meta.abort.asSignal(),
    },
  );

  const documentType =
    getDocumentTypeFromContentType(response.headers.get("content-type")) ??
    getDocumentTypeFromUrl(response.url);

  const html = await converter.convertBufferToHtml(
    new Uint8Array(buffer),
    documentType,
  );

  return {
    url: response.url,
    statusCode: response.status,
    html,
    proxyUsed: "basic",
  };
}

export function documentMaxReasonableTime(meta: Meta): number {
  return 15000;
}
