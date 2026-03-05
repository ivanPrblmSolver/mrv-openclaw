import { EnvHttpProxyAgent, setGlobalDispatcher } from 'undici';

const proxyUrl = process.env.HTTPS_PROXY || process.env.HTTP_PROXY;
if (proxyUrl) {
  const proxyAgent = new EnvHttpProxyAgent();
  setGlobalDispatcher(proxyAgent);
  console.log(`[proxy-bootstrap] Using proxy: ${proxyUrl} (NO_PROXY: ${process.env.NO_PROXY || 'none'})`);
}
