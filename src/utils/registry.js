const map = new WeakMap();

export function register(dispatch, raw, chrono) {
  map.set(dispatch, { raw, chrono });
}

export function lookup(dispatch) {
  const v = map.get(dispatch);
  return v === undefined ? null : v;
}

export function unregister(dispatch) {
  return map.delete(dispatch);
}
