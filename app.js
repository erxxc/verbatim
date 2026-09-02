const composer = document.querySelector('#composer');
const stream = document.querySelector('#translationStream');
const template = document.querySelector('#translationTemplate');
const count = document.querySelector('#characterCount');
const hint = document.querySelector('.composer-hint');
const hintText = hint.querySelector('span:last-child');
const clearButton = document.querySelector('#clearButton');
const languageButton = document.querySelector('#languageButton');
const interfaceLanguage = document.querySelector('#interfaceLanguage');
const directionButton = document.querySelector('#directionButton');
const sourceFlag = document.querySelector('#sourceFlag');
const targetFlag = document.querySelector('#targetFlag');
const sourceLanguage = document.querySelector('#sourceLanguage');
const targetLanguage = document.querySelector('#targetLanguage');
const macroToggle = document.querySelector('#macroToggle');
const macroToggleLabel = document.querySelector('#macroToggleLabel');
const macroIndicator = document.querySelector('#macroIndicator');
const shortcutModifier = document.querySelector('#shortcutModifier');

const MAX_LENGTH = 500;
let processedLength = 0;
let uiLanguage = 'en';
let direction = 'en-ru';
let macroMode = true;
let queue = Promise.resolve();

const copy = {
  en: {
    eyebrow: 'ENGLISH ↔ РУССКИЙ', title: 'Write your thought.<br><em>We’ll find the words.</em>',
    intro: 'Finish a sentence and watch it become Russian—quietly, instantly, without breaking your flow.',
    english: 'English', russian: 'Russian', trigger: 'translates', hint: 'Type a sentence; punctuation will replace it in Russian',
    translating: 'Translating your sentence…', ready: 'Ready for the next sentence', clear: 'Clear',
    macroTitle: 'Macro mode', macroDescription: 'Replace each completed sentence inside the editor', on: 'On', off: 'Off',
    flowTitle: 'Keep your flow', flowBody: 'Press ⌘⇧M from anywhere in the app. Punctuation replaces the completed sentence.',
    contextTitle: 'Built for context', contextBody: 'Every sentence stays paired with its original, so meaning is easy to follow.',
    localTitle: 'Graceful offline mode', localBody: 'Common phrases translate on device; richer translation is used when available.',
    footer: 'Made for thoughts that travel.', placeholder: 'Start writing in English…'
  },
  ru: {
    eyebrow: 'АНГЛИЙСКИЙ → РУССКИЙ', title: 'Запишите свою мысль.<br><em>Мы подберём слова.</em>',
    intro: 'Закончите предложение — и оно станет русским мгновенно, не прерывая ход ваших мыслей.',
    english: 'Английский', russian: 'Русский', trigger: 'перевести', hint: 'Введите предложение — знак препинания заменит его переводом',
    translating: 'Переводим предложение…', ready: 'Можно писать следующее предложение', clear: 'Очистить',
    macroTitle: 'Режим макроса', macroDescription: 'Заменять завершённое предложение прямо в редакторе', on: 'Вкл', off: 'Выкл',
    flowTitle: 'Не теряйте мысль', flowBody: 'Нажмите ⌘⇧M в приложении. Знак препинания заменит завершённую фразу.',
    contextTitle: 'Контекст сохранён', contextBody: 'Перевод всегда находится рядом с оригиналом — смысл легко проследить.',
    localTitle: 'Работает офлайн', localBody: 'Частые фразы переводятся на устройстве, а при подключении доступен полный перевод.',
    footer: 'Для мыслей, которые путешествуют.', placeholder: 'Начните писать по-английски…'
  }
};

const phrasebook = new Map(Object.entries({
  'hello.': 'Здравствуйте.', 'hello!': 'Здравствуйте!', 'hi.': 'Привет.', 'good morning.': 'Доброе утро.',
  'good afternoon.': 'Добрый день.', 'good evening.': 'Добрый вечер.', 'good night.': 'Спокойной ночи.',
  'how are you?': 'Как вы?', "how's it going?": 'Как дела?', 'i am fine.': 'У меня всё хорошо.',
  'thank you.': 'Спасибо.', 'thank you!': 'Спасибо!', 'thanks.': 'Спасибо.', 'you are welcome.': 'Пожалуйста.',
  'what is your name?': 'Как вас зовут?', 'my name is anna.': 'Меня зовут Анна.',
  'nice to meet you.': 'Приятно познакомиться.', 'where are you from?': 'Откуда вы?',
  'i am from new york.': 'Я из Нью-Йорка.', 'do you speak english?': 'Вы говорите по-английски?',
  'i do not understand.': 'Я не понимаю.', 'please speak slowly.': 'Пожалуйста, говорите медленнее.',
  'can you help me?': 'Вы можете мне помочь?', 'where is the train station?': 'Где находится вокзал?',
  'how much does this cost?': 'Сколько это стоит?', 'i would like some coffee.': 'Я бы хотел кофе.',
  'the weather is beautiful today.': 'Сегодня прекрасная погода.', 'today is a beautiful day.': 'Сегодня прекрасный день.',
  'i love learning new languages.': 'Я люблю изучать новые языки.',
  'language connects people.': 'Язык объединяет людей.', 'see you tomorrow.': 'До завтра.',
  'goodbye.': 'До свидания.', 'goodbye!': 'До свидания!'
}));

const wordbook = {
  i: 'я', we: 'мы', you: 'вы', he: 'он', she: 'она', they: 'они', this: 'это', that: 'то',
  love: 'люблю', like: 'нравится', want: 'хочу', need: 'нужно', have: 'есть', know: 'знаю',
  see: 'вижу', think: 'думаю', write: 'пишу', read: 'читаю', learn: 'изучаю', speak: 'говорю',
  a: '', an: '', the: '', my: 'мой', your: 'ваш', our: 'наш', new: 'новый', good: 'хороший',
  beautiful: 'прекрасный', small: 'маленький', big: 'большой', happy: 'счастлив', very: 'очень',
  today: 'сегодня', tomorrow: 'завтра', now: 'сейчас', home: 'дом', world: 'мир', book: 'книга',
  language: 'язык', russian: 'русский', english: 'английский', coffee: 'кофе', tea: 'чай',
  friend: 'друг', friends: 'друзья', family: 'семья', work: 'работа', music: 'музыка', and: 'и',
  but: 'но', with: 'с', without: 'без', in: 'в', from: 'из', to: 'к', is: '', are: '', am: ''
};

const reversePhrasebook = new Map([...phrasebook].map(([english, russian]) => [russian.toLowerCase(), english.charAt(0).toUpperCase() + english.slice(1)]));

function extractCompleteSentences(text) {
  const unprocessed = text.slice(processedLength);
  const matches = [...unprocessed.matchAll(/[^.!?\n]+(?:[.!?]+|\n)/g)];
  const results = [];
  let consumed = 0;
  for (const match of matches) {
    const sentence = match[0].trim();
    consumed = match.index + match[0].length;
    if (sentence && /[.!?]$/.test(sentence)) results.push(sentence);
  }
  processedLength += consumed;
  return results;
}

function offlineTranslate(sentence, languageDirection = direction) {
  const dictionary = languageDirection === 'en-ru' ? phrasebook : reversePhrasebook;
  const exact = dictionary.get(sentence.trim().toLowerCase());
  if (exact) return exact;
  if (languageDirection === 'ru-en') return sentence;
  const punctuation = sentence.match(/[.!?]+$/)?.[0] || '.';
  const body = sentence.replace(/[.!?]+$/, '').toLowerCase();
  const translated = body.split(/(\s+|[,;:])/).map(token => {
    if (/^\s+$|^[,;:]$/.test(token)) return token;
    return Object.prototype.hasOwnProperty.call(wordbook, token) ? wordbook[token] : token;
  }).filter(Boolean).join('').replace(/\s+/g, ' ').trim();
  return translated.charAt(0).toUpperCase() + translated.slice(1) + punctuation;
}

async function translate(sentence, languageDirection = direction) {
  // Keep familiar phrases on-device; use the public service only for broader vocabulary.
  const localDictionary = languageDirection === 'en-ru' ? phrasebook : reversePhrasebook;
  const localMatch = localDictionary.get(sentence.trim().toLowerCase());
  if (localMatch) return localMatch;
  try {
    const pair = languageDirection === 'en-ru' ? 'en|ru' : 'ru|en';
    const url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(sentence)}&langpair=${pair}`;
    const response = await fetch(url, { signal: AbortSignal.timeout(4500) });
    if (!response.ok) throw new Error('Translation service unavailable');
    const data = await response.json();
    const result = data?.responseData?.translatedText;
    if (result && !/MYMEMORY WARNING/i.test(result)) return result;
  } catch (_) { /* Fall back locally. */ }
  return offlineTranslate(sentence, languageDirection);
}

function lastSentenceRange(value, caret) {
  const beforeCaret = value.slice(0, caret);
  const end = caret;
  const punctuationIndex = Math.max(
    beforeCaret.lastIndexOf('.', end - 2),
    beforeCaret.lastIndexOf('!', end - 2),
    beforeCaret.lastIndexOf('?', end - 2),
    beforeCaret.lastIndexOf('\n', end - 2)
  );
  const start = punctuationIndex + 1;
  const leading = value.slice(start, end).match(/^\s*/)?.[0].length || 0;
  return { start: start + leading, end };
}

async function replaceLastSentence(event) {
  if (!macroMode || event.inputType !== 'insertText' || !/[.!?]/.test(event.data || '')) return false;
  const caret = composer.selectionStart;
  const range = lastSentenceRange(composer.value, caret);
  const original = composer.value.slice(range.start, range.end);
  if (!original.trim()) return true;
  const requestedDirection = direction;
  setHint('translating');
  const translated = await translate(original, requestedDirection);
  if (composer.value.slice(range.start, range.end) !== original) return true;
  const selectionStart = composer.selectionStart;
  const selectionEnd = composer.selectionEnd;
  composer.setRangeText(translated, range.start, range.end, 'preserve');
  if (composer.value.length > MAX_LENGTH) composer.value = composer.value.slice(0, MAX_LENGTH);
  const delta = translated.length - original.length;
  if (selectionStart >= range.end) composer.setSelectionRange(selectionStart + delta, selectionEnd + delta);
  count.textContent = `${composer.value.length} / ${MAX_LENGTH}`;
  setHint('ready');
  return true;
}

function setHint(state) {
  hint.classList.toggle('is-translating', state === 'translating');
  hintText.textContent = copy[uiLanguage][state] || copy[uiLanguage].hint;
}

function addPair(original, russian) {
  const fragment = template.content.cloneNode(true);
  fragment.querySelector('.original-text').textContent = original;
  fragment.querySelector('.russian-text').textContent = russian;
  const copyButton = fragment.querySelector('.copy-button');
  copyButton.addEventListener('click', async () => {
    await navigator.clipboard.writeText(russian);
    copyButton.querySelector('span').textContent = uiLanguage === 'ru' ? 'Готово' : 'Copied';
    setTimeout(() => copyButton.querySelector('span').textContent = uiLanguage === 'ru' ? 'Копировать' : 'Copy', 1400);
  });
  stream.appendChild(fragment);
  stream.lastElementChild.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

composer.addEventListener('input', async event => {
  if (composer.value.length > MAX_LENGTH) composer.value = composer.value.slice(0, MAX_LENGTH);
  count.textContent = `${composer.value.length} / ${MAX_LENGTH}`;
  if (await replaceLastSentence(event)) return;
  if (composer.value.length < processedLength) processedLength = 0;
  const sentences = extractCompleteSentences(composer.value);
  for (const sentence of sentences) {
    queue = queue.then(async () => {
      setHint('translating');
      const russian = await translate(sentence);
      addPair(sentence, russian);
      setHint('ready');
    });
  }
  if (!sentences.length && !hint.classList.contains('is-translating')) setHint('hint');
});

function updateDirection() {
  const isEnglishSource = direction === 'en-ru';
  sourceFlag.textContent = isEnglishSource ? 'EN' : 'РУ';
  targetFlag.textContent = isEnglishSource ? 'РУ' : 'EN';
  sourceFlag.className = `flag ${isEnglishSource ? 'flag-en' : 'flag-ru'}`;
  targetFlag.className = `flag ${isEnglishSource ? 'flag-ru' : 'flag-en'}`;
  sourceLanguage.textContent = copy[uiLanguage][isEnglishSource ? 'english' : 'russian'];
  targetLanguage.textContent = copy[uiLanguage][isEnglishSource ? 'russian' : 'english'];
  composer.placeholder = isEnglishSource
    ? copy[uiLanguage].placeholder
    : (uiLanguage === 'ru' ? 'Начните писать по-русски…' : 'Start writing in Russian…');
  if (macroMode) hintText.textContent = isEnglishSource
    ? copy[uiLanguage].hint
    : (uiLanguage === 'ru' ? 'Введите предложение — оно будет заменено английским переводом' : 'Type a sentence; punctuation will replace it in English');
}

function setMacroMode(enabled) {
  macroMode = enabled;
  macroToggle.setAttribute('aria-checked', String(enabled));
  macroToggleLabel.textContent = copy[uiLanguage][enabled ? 'on' : 'off'];
  macroIndicator.classList.toggle('is-active', enabled);
  processedLength = composer.value.length;
  setHint('hint');
  updateDirection();
}

directionButton.addEventListener('click', () => {
  direction = direction === 'en-ru' ? 'ru-en' : 'en-ru';
  updateDirection();
  composer.focus();
});

macroToggle.addEventListener('click', () => setMacroMode(!macroMode));

document.addEventListener('keydown', event => {
  if ((event.metaKey || event.ctrlKey) && event.shiftKey && event.key.toLowerCase() === 'm') {
    event.preventDefault();
    setMacroMode(!macroMode);
    composer.focus();
  }
});

clearButton.addEventListener('click', () => {
  composer.value = '';
  stream.replaceChildren();
  processedLength = 0;
  count.textContent = `0 / ${MAX_LENGTH}`;
  setHint('hint');
  composer.focus();
});

languageButton.addEventListener('click', () => {
  uiLanguage = uiLanguage === 'en' ? 'ru' : 'en';
  interfaceLanguage.textContent = uiLanguage.toUpperCase();
  document.documentElement.lang = uiLanguage;
  document.querySelectorAll('[data-copy]').forEach(node => {
    const key = node.dataset.copy;
    if (copy[uiLanguage][key]) node.innerHTML = copy[uiLanguage][key];
  });
  composer.placeholder = copy[uiLanguage].placeholder;
  macroToggleLabel.textContent = copy[uiLanguage][macroMode ? 'on' : 'off'];
  setHint('hint');
  updateDirection();
});

shortcutModifier.textContent = /Mac|iPhone|iPad/.test(navigator.platform) ? '⌘' : 'Ctrl';
const startup = new URLSearchParams(window.location.search);
if (startup.get('direction') === 'ru-en') direction = 'ru-en';
setMacroMode(startup.get('macro') !== '0');

// Stable hooks for browser shortcuts, bookmarklets, Stream Deck, and other macro tools.
window.Verbatim = Object.freeze({
  start: () => setMacroMode(true),
  stop: () => setMacroMode(false),
  toggle: () => setMacroMode(!macroMode),
  swap: () => {
    direction = direction === 'en-ru' ? 'ru-en' : 'en-ru';
    updateDirection();
    return direction;
  },
  state: () => ({ active: macroMode, direction })
});
composer.focus();
