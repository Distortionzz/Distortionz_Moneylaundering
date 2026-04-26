Config = {}

Config.Debug = false

Config.ResourceName = 'distortionz_moneylaundering'
Config.CurrentVersion = '1.0.2'

Config.VersionCheck = {
    enabled = false,

    -- Change this to your real GitHub raw version.json URL when uploaded.
    url = 'https://raw.githubusercontent.com/YOUR_GITHUB/YOUR_REPO/main/distortionz_moneylaundering/version.json',

    checkOnStart = true
}

Config.Notify = {
    title = 'Money Laundering',
    useDistortionzNotify = true
}

Config.Items = {
    dirtyMoney = 'black_money'
}

Config.Laundering = {
    minAmount = 1000,
    maxAmount = 50000,

    -- 75 means player receives 75% clean cash.
    cleanRate = 75,

    processTime = 20,
    cooldown = 10 * 60,

    -- If true, dirty money is removed when the process starts.
    -- If cancelled, it gets returned.
    removeDirtyMoneyOnStart = true,

    -- If true, player must stay near the laundering ped.
    requireStayNearPed = true,
    cancelDistance = 12.0
}

Config.Police = {
    enabled = true,

    -- Chance police receive alert when laundering begins.
    alertChance = 25,

    jobs = {
        police = true,
        sheriff = true,
        state = true
    },

    alertBlip = {
        sprite = 500,
        color = 1,
        scale = 1.0,
        duration = 60
    }
}

Config.Locations = {
    {
        name = 'Industrial Launderer',
        pedModel = 'g_m_m_chicold_01',
        coords = vec4(891.29, -956.96, 43.18, 217.52),
        scenario = 'WORLD_HUMAN_SMOKING',

        blip = {
            enabled = true,
            sprite = 500,
            color = 1,
            scale = 0.75,
            label = 'Money Laundering',
            shortRange = true
        },

        target = {
            icon = 'fa-solid fa-sack-dollar',
            label = 'Clean Dirty Money',
            distance = 2.0
        }
    }
}