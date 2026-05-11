import Constants from "expo-constants";
import { NativeModules } from "react-native";

const DEFAULT_PROXY_PORT = "8787";

function makeApiBase(hostLike: string | undefined): string | undefined {
  if (!hostLike) {
    return undefined;
  }

  const trimmed = hostLike.trim();
  if (!trimmed) {
    return undefined;
  }

  if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
    try {
      const url = new URL(trimmed);
      return `${url.protocol}//${url.hostname}:${DEFAULT_PROXY_PORT}`;
    } catch {
      return undefined;
    }
  }

  const withoutProtocol = trimmed.replace(/^[a-z]+:\/\//i, "");
  const host = withoutProtocol.split("/")[0]?.split(":")[0];
  if (!host) {
    return undefined;
  }

  return `http://${host}:${DEFAULT_PROXY_PORT}`;
}

export function inferDevApiBase(): string | undefined {
  const explicit = process.env.EXPO_PUBLIC_COACH_API_BASE_URL;
  if (explicit) {
    return makeApiBase(explicit);
  }

  const scriptURL = NativeModules?.SourceCode?.scriptURL as string | undefined;
  const fromScript = makeApiBase(scriptURL);
  if (fromScript) {
    return fromScript;
  }

  const fromExpoConfig = makeApiBase(
    Constants.expoConfig?.hostUri ||
      (Constants.manifest as { hostUri?: string } | null)?.hostUri ||
      Constants.linkingUri
  );
  if (fromExpoConfig) {
    return fromExpoConfig;
  }

  return makeApiBase("http://127.0.0.1");
}
