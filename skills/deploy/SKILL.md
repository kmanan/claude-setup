---
name: deploy
description: Build and deploy artfall-landing via PM2
user_invocable: true
---

Deploy the artfall-landing site. Run these steps sequentially and report results:

1. `cd /home/manan/artfall-landing && npm install --legacy-peer-deps`
2. `cd /home/manan/artfall-landing && npm run build`
3. `pm2 restart artfall-landing`
4. Wait 3 seconds, then `pm2 status artfall-landing` to verify it's online
5. `pm2 logs artfall-landing --lines 5 --nostream` to check for startup errors

If any step fails, stop and report the error. Do not continue to the next step.
