/* UV1200 웹 컨트롤 서비스 워커: 앱 파일을 저장해 두고 인터넷 없이도 실행되게 합니다.
   새 버전을 올릴 때는 VERSION 값을 바꾸면, 앱이 "새 버전" 알림을 띄웁니다. */
const VERSION='uv1200-0.8.2';
/* 같은 주소(예: github.io)에 다른 사이트가 있어도 서로의 저장 파일을 지우지 않도록, 캐시 이름에 이 앱 이름과 위치를 붙임 */
const SCOPE_TAG='@'+self.registration.scope;const CACHE=VERSION+SCOPE_TAG;
const ASSETS=['./','./index.html','./manifest.webmanifest','./icons/icon-192.png','./icons/icon-512.png','./icons/icon-maskable-192.png','./icons/icon-maskable-512.png','./icons/apple-touch-icon.png','./icons/favicon-32.png'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ASSETS.map(u=>new Request(u,{cache:'reload'})))))});
self.addEventListener('activate',e=>{e.waitUntil((async()=>{for(const k of await caches.keys())if(k!==CACHE&&k.startsWith('uv1200-')&&k.endsWith(SCOPE_TAG))await caches.delete(k);await self.clients.claim()})())});
self.addEventListener('message',e=>{if(e.data==='skipWaiting')self.skipWaiting()});
self.addEventListener('fetch',e=>{const r=e.request;if(r.method!=='GET')return;const u=new URL(r.url);if(u.origin!==location.origin)return;
  if(r.mode==='navigate'){e.respondWith((async()=>{const c=await caches.open(CACHE);return (await c.match('./index.html'))||(await c.match('./'))||fetch(r)})());return}
  e.respondWith((async()=>{const c=await caches.open(CACHE);const hit=await c.match(r,{ignoreSearch:true});if(hit)return hit;
    try{const res=await fetch(r);if(res.ok)c.put(r,res.clone());return res}catch(err){return new Response('',{status:504})}})())});
