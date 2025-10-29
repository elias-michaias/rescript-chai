import { useCallback, useEffect, useMemo, useReducer, useRef, useDebugValue } from 'react';
import { affectedToPathList, createProxy, isChanged } from 'proxy-compare';

export const useAffectedDebugValue = (state, affected) => {
  const pathList = useRef(undefined);
  useEffect(() => {
    pathList.current = affectedToPathList(state, affected);
  });
  useDebugValue(state);
};

const hasGlobalProcess = typeof process === 'object';

const condUseAffectedDebugValue = useAffectedDebugValue;

export const createTrackedSelector = (useSelector) => {
  const useTrackedSelector = () => {
    const [, forceUpdate] = useReducer((c) => c + 1, 0);
    // per-hook affected, it's not ideal but memo compatible
    const affected = useMemo(() => new WeakMap(), []);
    const prevState = useRef(undefined);
    const lastState = useRef(undefined);
    useEffect(() => {
      if (
        prevState.current !== lastState.current &&
        isChanged(prevState.current, lastState.current, affected, new WeakMap())
      ) {
        prevState.current = lastState.current;
        forceUpdate();
      }
    });
    const selector = useCallback(
      (nextState) => {
        lastState.current = nextState;
        if (
          prevState.current &&
          prevState.current !== nextState &&
          !isChanged(prevState.current, nextState, affected, new WeakMap())
        ) {
          return prevState.current;
        }
        prevState.current = nextState;
        return nextState;
      },
      [affected],
    );
    const state = useSelector(selector);
    if (hasGlobalProcess && process.env.NODE_ENV !== 'production') {
      condUseAffectedDebugValue(state, affected);
    }
    const proxyCache = useMemo(() => new WeakMap(), []); // per-hook proxyCache
    return createProxy(state, affected, proxyCache);
  };
  return useTrackedSelector;
};