# Monarch API

A collection of lightweight FiveM utility APIs

## FEATURES
- Each API runs in a sandboxed environment, so any global variables defined within an API won't 
pollute the resource's global scope.
- Circular dependency detection.
- A coroutine-based pending queue for resources attempting to access mnr before mnr_api is ready.
- A self-replacing stub proxy that supports both callable and table-style API access before 
mnr_api is ready.
- A proprietary file importer that supports loading cached or uncached Lua/JSON.
- A bidirectional RPC system with sequential key generation and timeout support.

## LICENSE
Copyright (c) 2025 Monarch Devs | All rights reserved.

Permission is hereby granted to any individual or organization to use this software solely within the context of a FiveM game server. Modification of this software for personal or internal use is permitted, provided that such modifications are not distributed in any form.

The following are expressly prohibited without prior written permission from Monarch Devs:
- Redistribution of this software, in whole or in part, in original or modified form.
- Sublicensing, selling, or otherwise transferring rights to this software to any third party.
- Use of this software outside of the FiveM game server context.

THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT. IN NO EVENT SHALL MONARCH DEVS OR ITS CONTRIBUTORS BE LIABLE FOR ANY CLAIM, DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING FROM, OUT OF, OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## LINKS
- [Discord](https://discord.gg/WKtk65yBC6)
- Documentation (Coming Soon)
- Cfx Forum Post (Coming Soon)
- [Repository](https://github.com/Monarch-Devs/mnr_api)