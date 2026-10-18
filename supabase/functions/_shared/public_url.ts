/** Literal/hostname guard, aligned with database rules. Not a DNS/egress firewall. */
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
  if (
    !host ||
    [
      "localhost",
      "localhost.localdomain",
      "metadata",
      "metadata.google.internal",
    ].includes(host) ||
    /\.(localhost|local|internal|home\.arpa)$/.test(host)
  ) return false;
  if (host.includes(":")) {
    const halves = host.split("::");
    const left = halves[0] ? halves[0].split(":") : [];
    const right = halves[1] ? halves[1].split(":") : [];
    const words = (halves.length === 2
      ? [...left, ...Array(8 - left.length - right.length).fill("0"), ...right]
      : left).map((n) =>
        parseInt(n, 16)
      );
    if (
      words.length !== 8 || words.some((n) =>
        !Number.isInteger(n) || n < 0 || n > 65535
      )
    ) {
      return false;
    }
    // ::/96 and ::ffff:0:0/96 include obfuscated IPv4 loopback/metadata forms.
    if (
      words.slice(0, 6).every((n) =>
        n === 0
      ) ||
      (words.slice(0, 5).every((n) => n === 0) && words[5] === 65535)
    ) return false;
    return (words[0] & 0xffc0) !== 0xfe80 && (words[0] & 0xfe00) !== 0xfc00 &&
      (words[0] & 0xff00) !== 0xff00;
  }
  if (/^[0-9.]+$/.test(host)) {
    const octets = host.split(".").map(Number);
    if (
      octets.length !== 4 ||
      octets.some((n) => !Number.isInteger(n) || n < 0 || n > 255)
    ) return false;
    const [a, b, c] = octets;
    return !(a === 0 || a === 10 || a === 127 || a >= 224 ||
      (a === 100 && b >= 64 && b <= 127) ||
      (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && (b === 168 || (b === 0 && (c === 0 || c === 2)))) ||
      (a === 198 && (b === 18 || b === 19 || (b === 51 && c === 100))) ||
      (a === 203 && b === 0 && c === 113));
  }
  return true;
}
