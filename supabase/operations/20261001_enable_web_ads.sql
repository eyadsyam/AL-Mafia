-- Run only after the tested web build is ready to publish. The H5 provider is
-- tried first; house art fills all no-fill and unapproved inventory.
update public.economy_config
set web_ads_enabled = true,
    web_ads_provider = 'adsense',
    web_interstitial_every_matches = 1,
    web_app_open_enabled = true,
    web_banner_always = true
where id = true;
