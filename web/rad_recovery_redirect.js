/* Normalize the legacy Supabase allowlisted hash callback before Flutter
   initializes its path-based GoRouter and Supabase PKCE session parser.
   Never log or persist recovery codes/tokens. */
(() => {
  const prefix = '#/reset-password';
  const hash = window.location.hash;
  if (hash !== prefix &&
      !hash.startsWith(prefix + '?') &&
      !hash.startsWith(prefix + '#')) {
    return;
  }

  const target = new URL(hash.slice(1), window.location.origin);
  // Supabase callbacks may append ?code either before or after the route hash.
  new URLSearchParams(window.location.search).forEach((value, key) => {
    if (!target.searchParams.has(key)) target.searchParams.append(key, value);
  });
  window.history.replaceState(
    window.history.state, '', target.pathname + target.search + target.hash,
  );
})();
