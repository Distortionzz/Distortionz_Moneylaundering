const app = document.getElementById('app');

const closeBtn = document.getElementById('closeBtn');
const maxBtn = document.getElementById('maxBtn');
const startBtn = document.getElementById('startBtn');

const locationName = document.getElementById('locationName');
const dirtyMoney = document.getElementById('dirtyMoney');
const cleanRate = document.getElementById('cleanRate');
const feeRate = document.getElementById('feeRate');
const minAmount = document.getElementById('minAmount');
const maxAmount = document.getElementById('maxAmount');

const amountInput = document.getElementById('amountInput');
const amountRange = document.getElementById('amountRange');
const selectedAmount = document.getElementById('selectedAmount');
const maxCleanableText = document.getElementById('maxCleanableText');

const summaryDirty = document.getElementById('summaryDirty');
const summaryFee = document.getElementById('summaryFee');
const summaryClean = document.getElementById('summaryClean');
const errorText = document.getElementById('errorText');

let state = {
    dirtyMoney: 0,
    minAmount: 0,
    maxAmount: 0,
    maxCleanable: 0,
    cleanRate: 0,
    feeRate: 0
};

function formatMoney(value) {
    const number = Number(value) || 0;

    return '$' + number.toLocaleString('en-US', {
        maximumFractionDigits: 0
    });
}

function postNui(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(data)
    }).then((response) => response.json());
}

function calculateClean(amount) {
    return Math.floor(amount * (state.cleanRate / 100));
}

function calculateFee(amount) {
    return Math.floor(amount - calculateClean(amount));
}

function clampAmount(value) {
    let amount = Number(value) || 0;

    if (amount < 0) amount = 0;
    if (amount > state.maxCleanable) amount = state.maxCleanable;

    return Math.floor(amount);
}

function setError(message) {
    errorText.textContent = message || '';
}

function updatePreview(value) {
    const amount = clampAmount(value);
    const clean = calculateClean(amount);
    const fee = calculateFee(amount);

    amountInput.value = amount;
    amountRange.value = amount;

    selectedAmount.textContent = formatMoney(amount);
    summaryDirty.textContent = formatMoney(amount);
    summaryFee.textContent = '-' + formatMoney(fee);
    summaryClean.textContent = formatMoney(clean);

    if (state.maxCleanable < state.minAmount) {
        startBtn.disabled = true;
        setError(`You need at least ${formatMoney(state.minAmount)} dirty money.`);
        return;
    }

    if (amount < state.minAmount) {
        startBtn.disabled = true;
        setError(`Minimum amount is ${formatMoney(state.minAmount)}.`);
        return;
    }

    startBtn.disabled = false;
    setError('');
}

function openUI(data) {
    state = {
        dirtyMoney: Number(data.dirtyMoney) || 0,
        minAmount: Number(data.minAmount) || 0,
        maxAmount: Number(data.maxAmount) || 0,
        maxCleanable: Number(data.maxCleanable) || 0,
        cleanRate: Number(data.cleanRate) || 0,
        feeRate: Number(data.feeRate) || 0
    };

    locationName.textContent = data.locationName || 'Unknown Location';

    dirtyMoney.textContent = formatMoney(state.dirtyMoney);
    cleanRate.textContent = `${state.cleanRate}%`;
    feeRate.textContent = `${state.feeRate}%`;
    minAmount.textContent = formatMoney(state.minAmount);
    maxAmount.textContent = formatMoney(state.maxAmount);

    amountInput.min = 0;
    amountInput.max = state.maxCleanable;

    amountRange.min = 0;
    amountRange.max = state.maxCleanable;

    maxCleanableText.textContent = `You can clean up to ${formatMoney(state.maxCleanable)} right now.`;

    const startingAmount = state.maxCleanable >= state.minAmount ? state.maxCleanable : 0;

    app.classList.remove('hidden');
    updatePreview(startingAmount);
}

function closeUI() {
    app.classList.add('hidden');
    setError('');
}

window.addEventListener('message', (event) => {
    const payload = event.data;

    if (!payload || !payload.action) return;

    if (payload.action === 'open') {
        openUI(payload.data || {});
    }

    if (payload.action === 'close') {
        closeUI();
    }
});

amountInput.addEventListener('input', () => {
    updatePreview(amountInput.value);
});

amountRange.addEventListener('input', () => {
    updatePreview(amountRange.value);
});

maxBtn.addEventListener('click', () => {
    updatePreview(state.maxCleanable);
});

closeBtn.addEventListener('click', () => {
    postNui('close').then(() => {
        closeUI();
    });
});

startBtn.addEventListener('click', () => {
    const amount = clampAmount(amountInput.value);

    startBtn.disabled = true;
    setError('');

    postNui('startLaunder', {
        amount
    }).then((result) => {
        if (!result || !result.success) {
            setError(result && result.message ? result.message : 'Unable to start laundering.');
            updatePreview(amount);
            return;
        }

        closeUI();
    }).catch(() => {
        setError('NUI callback failed.');
        updatePreview(amount);
    });
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        postNui('close').then(() => {
            closeUI();
        });
    }
});