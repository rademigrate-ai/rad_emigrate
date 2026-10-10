function parseIpv4(host: string): number[] | null {
  const match = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (!match) return null;
  const octets = match.slice(1).map(Number);
  return octets.some((part) => part > 255) ? null : octets;
}

function parseIpv6(host: string): number[] | null {
  if (host.includes("%")) return null;
  const sections = host.split("::");
  if (sections.length > 2) return null;

  const parseSection = (section: string): number[] | null => {
    if (!section) return [];
    const parts = section.split(":");
    const words: number[] = [];
    for (const part of parts) {
      if (part.includes(".")) {
        const octets = parseIpv4(part);
        if (!octets) return null;
        words.push((octets[0] << 8) | octets[1]);
        words.push((octets[2] << 8) | octets[3]);
        continue;
      }
      if (!/^[0-9a-f]{1,4}$/i.test(part)) return null;
      words.push(parseInt(part, 16));
    }
    return words;
  };

  const left = parseSection(sections[0]);
  const right = sections.length === 2 ? parseSection(sections[1]) : [];
  if (!left || !right) return null;
  if (sections.length === 1) return left.length === 8 ? left : null;
  if (left.length + right.length >= 8) return null;
  return [...left, ...Array(8 - left.length - right.length).fill(0), ...right];
}

function isNonPublicIpv4(octets: number[]): boolean {
  const [a, b] = octets;
  return a === 0 || a === 10 || a === 127 ||
    (a === 169 && b === 254) ||
    (a === 172 && b >= 16 && b <= 31) ||
    (a === 192 && b === 168) ||
    (a === 100 && b >= 64 && b <= 127) ||
    a >= 224;
}

function isNonPublicIpv6(words: number[]): boolean {
  // Reject IPv4-compatible and IPv4-mapped forms outright. This covers
  // dotted, compressed, and canonical hexadecimal spellings consistently.
  const mappedPrefix = words.slice(0, 5).every((word) => word === 0) &&
    words[5] === 0xffff;
  const compatiblePrefix = words.slice(0, 6).every((word) => word === 0);
  if (mappedPrefix || compatiblePrefix) return true;

  const first = words[0];
  return words.every((word) => word === 0) ||
    (words.slice(0, 7).every((word) => word === 0) && words[7] === 1) ||
    (first & 0xffc0) === 0xfe80 ||
    (first & 0xfe00) === 0xfc00 ||
    (first & 0xff00) === 0xff00;
}

export function isSafePublicHttpsUrl(value: string): boolean {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    return false;
  }
  if (url.protocol !== "https:" || url.username || url.password) return false;

  const host = url.hostname.toLowerCase().replace(/^\[|\]$/g, "").replace(
    /\.$/,
    "",
  );
  if (!host || host.includes("%")) return false;
  if (
    [
      "localhost",
      "localhost.localdomain",
      "0.0.0.0",
      "metadata",
      "metadata.google.internal",
    ].includes(host)
  ) return false;
  if (
    host.endsWith(".localhost") || host.endsWith(".local") ||
    host.endsWith(".internal") || host.endsWith(".home.arpa")
  ) return false;

  if (host.includes(":")) {
    const words = parseIpv6(host);
    return words !== null && !isNonPublicIpv6(words);
  }
  const ipv4 = parseIpv4(host);
  if (ipv4) return !isNonPublicIpv4(ipv4);
  if (/^\d+$/.test(host)) return false;
  return true;
}
