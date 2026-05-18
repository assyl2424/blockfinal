import { http, createConfig } from 'wagmi';
import { arbitrumSepolia, baseSepolia, localhost } from 'wagmi/chains';
import { injected } from 'wagmi/connectors';

export const config = createConfig({
  chains: [arbitrumSepolia, baseSepolia, localhost],
  connectors: [
    injected({ target: 'metaMask' })
  ],
  transports: {
    [arbitrumSepolia.id]: http(),
    [baseSepolia.id]: http(),
    [localhost.id]: http(),
  },
});
