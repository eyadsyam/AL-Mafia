import { chromium, devices, webkit } from 'playwright';
import { join } from 'node:path';

const baseUrl = process.argv[2] ?? 'http://127.0.0.1:8765';
const appUrl = new URL('/?web=1', baseUrl).toString();
const cases = [
  ['chromium-android', chromium, devices['Pixel 5']],
  ['webkit-iphone', webkit, devices['iPhone 13']],
];

for (const [name, engine, device] of cases) {
  const executablePath = name === 'chromium-android'
    ? join(
        process.env.LOCALAPPDATA,
        'ms-playwright',
        'chromium_headless_shell-1217',
        'chrome-headless-shell-win64',
        'chrome-headless-shell.exe',
      )
    : undefined;
  const browser = await engine.launch({ headless: true, executablePath });
  const context = await browser.newContext(device);
  const page = await context.newPage();
  page.on('console', (message) =>
    console.error(`${name}:console:${message.type()}:${message.text()}`),
  );
  page.on('pageerror', (error) =>
    console.error(`${name}:pageerror:${error.message}`),
  );
  page.on('requestfailed', (request) =>
    console.error(`${name}:requestfailed:${request.url()}:${request.failure()?.errorText}`),
  );
  await page.goto(appUrl, { waitUntil: 'commit' });

  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 60_000 });
  await placeholder.click({ force: true });
  const button = page.getByRole('button', { name: /إنستا باي/ });
  await button.waitFor({ state: 'visible', timeout: 60_000 });
  const popupPromise = page.waitForEvent('popup');
  const destinationPromise = context.waitForEvent('request', {
    predicate: (request) =>
      request.url() === 'https://127.0.0.1:9443/a1-payment',
  });
  await button.click();
  const popup = await popupPromise;
  const destination = await destinationPromise;

  const failedCopy = page.getByText(
    'المتصفح ما فتحش الصفحة. اسمح بالنوافذ الجديدة للموقع وجرّب تاني.',
  );
  const result = {
    browser: name,
    viewport: page.viewportSize(),
    popupUrl: destination.url(),
    failedMessageCount: await failedCopy.count(),
  };
  console.log(JSON.stringify(result));
  await page.screenshot({ path: `build/a1-evidence/web-${name}.png` });
  await browser.close();
}
