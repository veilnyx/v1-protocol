import { decodeAbiParameters, parseAbiParameters } from 'viem';

const payload = '0x00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000014E0be19De3118b5b29842dd1696a2A98EB9Db';

// Decode as (uint8 action, address vault)
const decoded = decodeAbiParameters(
    parseAbiParameters('uint8 action, address vault'),
    payload as `0x${string}`
);

console.log('Decoded values:');
console.log('  action (uint8):', decoded[0]);
console.log('  vault (address):', decoded[1]);
console.log('\nRaw decoded array:', decoded);