/** Preserve async-stub semantics: run synchronously, resolve values, reject throws. */
export function promiseStub<Args extends unknown[], Result>(
  action: (...args: Args) => Result,
): (...args: Args) => Promise<Awaited<Result>> {
  return (...args) => {
    try {
      return Promise.resolve(action(...args));
    } catch (error) {
      return Promise.reject(error);
    }
  };
}
