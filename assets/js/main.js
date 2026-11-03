/* =====================================================================
   页面渲染逻辑 —— 读取 content.js 里的内容，生成整个页面。
   正常情况下你不需要改这个文件；改内容请打开 content.js。
   ===================================================================== */

(function () {
  'use strict';

  var S = window.SITE || {};
  var RENDERED = [];          // 已渲染的板块，用于生成导航

  /* ---------------------------------------------------------------- 小工具 */
  function el(tag, props, children) {
    var node = document.createElement(tag);
    if (props) {
      Object.keys(props).forEach(function (key) {
        var value = props[key];
        if (value === null || value === undefined || value === false || value === '') return;
        if (key === 'class') { node.className = value; }
        else if (key === 'text') { node.textContent = value; }
        else if (key === 'html') { node.innerHTML = value; }
        else if (key === 'dataset') {
          Object.keys(value).forEach(function (dataKey) { node.dataset[dataKey] = value[dataKey]; });
        } else {
          node.setAttribute(key, value === true ? '' : value);
        }
      });
    }
    return append(node, children);
  }

  function append(node, children) {
    if (children === null || children === undefined || children === false) return node;
    if (!Array.isArray(children)) children = [children];
    children.forEach(function (child) {
      if (child === null || child === undefined || child === false || child === '') return;
      if (child instanceof Node) node.appendChild(child);
      else node.appendChild(document.createTextNode(String(child)));
    });
    return node;
  }

  function hasList(list) { return Array.isArray(list) && list.length > 0; }

  /* 导航文字：优先用 navLabel，否则从 kicker 里去掉 // 之类的装饰符号 */
  function cleanLabel(text) {
    return String(text === undefined || text === null ? '' : text)
      .replace(/^\/\/\s*/, '')
      .replace(/^<[^>]*>\s*/, '')
      .trim();
  }

  function navLabelOf(data) {
    return data.navLabel || cleanLabel(data.kicker) || data.title || '';
  }

  /* 把字符串里的 \n 变成换行 */
  function withBreaks(text) {
    var parts = String(text).split('\n');
    var out = [];
    parts.forEach(function (line, index) {
      if (index > 0) out.push(el('br'));
      out.push(line);
    });
    return out;
  }

  function chips(items) {
    return el('ul', { class: 'chips' }, items.map(function (item) {
      return el('li', { class: 'chip', text: item });
    }));
  }

  /* 统一的板块外壳：小标签 + 标题 + 副标题 */
  function sectionShell(id, data, options) {
    if (!data) return null;
    var opts = options || {};
    var section = el('section', { class: 'section reveal', id: id });
    var head = el('div', { class: 'section-head' });
    if (data.kicker) head.appendChild(el('p', { class: 'section-kicker', text: data.kicker }));
    if (data.title) head.appendChild(el('h2', { class: 'section-title', text: data.title }));
    if (data.subtitle) head.appendChild(el('p', { class: 'section-subtitle', text: data.subtitle }));
    var body = el('div', { class: 'section-body' });
    section.appendChild(head);
    section.appendChild(body);
    if (opts.nav !== false) {
      RENDERED.push({ id: id, label: navLabelOf(data) || id });
    }
    return { section: section, body: body, head: head };
  }

  function container(children, extraClass) {
    return el('div', { class: 'container' + (extraClass ? ' ' + extraClass : '') }, children);
  }

  /* ---------------------------------------------------------------- 首屏 */
  function renderHero() {
    var h = S.hero;
    if (!h || !h.name) return null;

    var text = el('div', { class: 'hero-text' });

    if (h.status) {
      text.appendChild(el('span', { class: 'status-chip' }, [
        el('span', { class: 'dot', 'aria-hidden': 'true' }),
        el('span', { text: h.status })
      ]));
    }

    var name = el('h1', {
      class: 'hero-name',
      text: h.name,
      'data-text': h.name + (h.nameAccent || '')
    });
    if (h.nameAccent) name.appendChild(el('span', { class: 'grad', text: h.nameAccent }));
    text.appendChild(name);

    if (h.role) text.appendChild(el('p', { class: 'hero-role', text: h.role }));
    if (h.intro) text.appendChild(el('p', { class: 'hero-intro' }, withBreaks(h.intro)));

    if (hasList(h.buttons)) {
      text.appendChild(el('div', { class: 'hero-actions' }, h.buttons.map(function (button) {
        return el('a', {
          class: 'btn ' + (button.style === 'primary' ? 'btn-primary' : 'btn-ghost'),
          href: button.href || '#',
          text: button.label
        });
      })));
    }

    var media = el('div', { class: 'hero-media' }, [
      el('div', { class: 'avatar-ring' }, [
        el('img', { class: 'avatar', src: h.avatar, alt: h.avatarAlt || '头像' })
      ])
    ]);

    var inner = container([text, media], 'hero-inner');
    var section = el('section', { class: 'hero-section', id: 'hero' }, [inner]);

    if (hasList(h.stats)) {
      inner.appendChild(el('ul', { class: 'stats' }, h.stats.map(function (stat) {
        return el('li', { class: 'stat' }, [
          el('strong', { class: 'stat-value', text: stat.value }),
          el('span', { class: 'stat-label', text: stat.label })
        ]);
      })));
    }

    if (hasList(h.ticker)) {
      var run = function (hidden) {
        return el('ul', {
          class: 'ticker-run',
          'aria-hidden': hidden ? 'true' : null
        }, h.ticker.map(function (word) {
          return el('li', { text: word });
        }));
      };
      inner.appendChild(el('div', { class: 'ticker' }, [
        el('div', { class: 'ticker-track' }, [run(false), run(true)])
      ]));
    }
    return section;
  }

  /* ---------------------------------------------------------------- 关于我 */
  function renderAbout() {
    var a = S.about;
    if (!a) return null;
    var shell = sectionShell('about', a);
    if (!shell) return null;

    var left = el('div', { class: 'about-text' });
    (a.paragraphs || []).forEach(function (paragraph) {
      if (paragraph) left.appendChild(el('p', {}, withBreaks(paragraph)));
    });
    if (a.quote) left.appendChild(el('p', { class: 'quote', text: a.quote }));

    var right = el('div', { class: 'about-side' });
    if (hasList(a.facts)) {
      right.appendChild(el('dl', { class: 'facts' }, (function () {
        var nodes = [];
        a.facts.forEach(function (fact) {
          nodes.push(el('dt', { text: fact.label }));
          nodes.push(el('dd', { text: fact.value }));
        });
        return nodes;
      })()));
    }
    if (hasList(a.keywords)) {
      right.appendChild(el('h3', { class: 'side-title', text: '关键词' }));
      right.appendChild(chips(a.keywords));
    }

    shell.body.appendChild(el('div', { class: 'about-grid' }, [left, right]));
    return shell.section;
  }

  /* ---------------------------------------------------------------- 技能 */
  function renderLife() {
    var d = S.life;
    if (!d || !hasList(d.items)) return null;
    var shell = sectionShell('life', d);
    if (!shell) return null;

    shell.body.appendChild(el('ol', { class: 'schedule' }, d.items.map(function (item) {
      var row = el('li', { class: 'schedule-row' }, [
        el('span', { class: 'schedule-time', text: item.time }),
        el('span', { class: 'schedule-node', 'aria-hidden': 'true' })
      ]);
      var box = el('div', { class: 'schedule-body' });
      var head = el('div', { class: 'schedule-head' }, [
        el('h3', { class: 'schedule-title', text: item.title })
      ]);
      if (item.tag) head.appendChild(el('span', { class: 'chip chip-tag', text: item.tag }));
      box.appendChild(head);
      if (item.desc) box.appendChild(el('p', { class: 'schedule-desc', text: item.desc }));
      row.appendChild(box);
      return row;
    })));
    return shell.section;
  }

  /* ---------------------------------------------------------------- 最近在玩 */
  function renderNow() {
    var d = S.now;
    if (!d || !hasList(d.items)) return null;
    var shell = sectionShell('now', d);
    if (!shell) return null;

    shell.body.appendChild(el('div', { class: 'now-grid' }, d.items.map(function (item) {
      var card = el('div', { class: 'card now-card' });
      if (item.label) card.appendChild(el('p', { class: 'now-label', text: item.label }));
      if (item.value) card.appendChild(el('p', { class: 'now-value', text: item.value }));
      if (item.note) card.appendChild(el('p', { class: 'now-note', text: item.note }));
      return card;
    })));
    return shell.section;
  }

  /* ---------------------------------------------------------------- 技能 */
  function renderSkills() {
    var s = S.skills;
    if (!s || !hasList(s.groups)) return null;
    var shell = sectionShell('skills', s);
    if (!shell) return null;

    shell.body.appendChild(el('div', { class: 'skill-grid' }, s.groups.map(function (group) {
      var card = el('div', { class: 'card skill-card' });
      card.appendChild(el('h3', { class: 'skill-name', text: group.name }));
      if (hasList(group.items)) card.appendChild(chips(group.items));
      return card;
    })));
    return shell.section;
  }

  /* ---------------------------------------------------------------- 作品 */
  function renderProjects() {
    var p = S.projects;
    if (!p || !hasList(p.items)) return null;
    var shell = sectionShell('projects', p);
    if (!shell) return null;

    shell.body.appendChild(el('div', { class: 'project-grid' }, p.items.map(function (item) {
      var card = el('article', { class: 'card project-card' });

      if (item.cover) {
        var cover = el('img', { class: 'project-cover', src: item.cover, alt: item.title || '项目封面', loading: 'lazy' });
        if (item.link) {
          card.appendChild(el('a', { class: 'project-cover-link', href: item.link, target: '_blank', rel: 'noopener' }, [cover]));
        } else {
          card.appendChild(el('div', { class: 'project-cover-link' }, [cover]));
        }
      }

      var info = el('div', { class: 'project-info' });
      if (hasList(item.tags)) {
        info.appendChild(el('ul', { class: 'chips chips-small' }, item.tags.map(function (tag) {
          return el('li', { class: 'chip', text: tag });
        })));
      }
      info.appendChild(el('h3', { class: 'project-title', text: item.title }));
      if (item.desc) info.appendChild(el('p', { class: 'project-desc', text: item.desc }));
      if (item.link) {
        info.appendChild(el('a', {
          class: 'link-arrow',
          href: item.link,
          target: '_blank',
          rel: 'noopener',
          text: (item.linkText || '查看详情') + ' ↗'
        }));
      }
      card.appendChild(info);
      return card;
    })));
    return shell.section;
  }

  /* ---------------------------------------------------------------- 时间线 */
  function renderTimeline() {
    var t = S.timeline;
    if (!t || !hasList(t.items)) return null;
    var shell = sectionShell('timeline', t);
    if (!shell) return null;

    shell.body.appendChild(el('ol', { class: 'timeline' }, t.items.map(function (item) {
      var entry = el('li', { class: 'timeline-item' }, [
        el('span', { class: 'timeline-dot', 'aria-hidden': 'true' }),
        el('span', { class: 'timeline-year', text: item.year })
      ]);
      var box = el('div', { class: 'timeline-box' });
      box.appendChild(el('h3', { class: 'timeline-title', text: item.title }));
      if (item.org) box.appendChild(el('p', { class: 'timeline-org', text: item.org }));
      if (item.desc) box.appendChild(el('p', { class: 'timeline-desc', text: item.desc }));
      entry.appendChild(box);
      return entry;
    })));
    return shell.section;
  }

  /* ---------------------------------------------------------------- 相册 */
  function renderGallery() {
    var g = S.gallery;
    if (!g || !hasList(g.items)) return null;
    var shell = sectionShell('gallery', g);
    if (!shell) return null;

    shell.body.appendChild(el('div', { class: 'gallery' }, g.items.map(function (item) {
      var figure = el('figure', { class: 'gallery-item' });
      figure.appendChild(el('button', { class: 'gallery-btn', type: 'button', 'aria-label': '放大图片：' + (item.caption || '') }, [
        el('img', { src: item.src, alt: item.caption || '照片', loading: 'lazy' })
      ]));
      if (item.caption) figure.appendChild(el('figcaption', { text: item.caption }));
      return figure;
    })));
    return shell.section;
  }

  /* ---------------------------------------------------------------- 自定义板块 */
  function renderCustom() {
    var items = S.custom;
    if (!hasList(items)) return null;
    var nodes = [];
    items.forEach(function (block, index) {
      if (!block) return;
      var id = block.id || ('custom-' + (index + 1));
      var fake = { kicker: block.kicker, title: block.title, subtitle: block.subtitle };
      var shell = sectionShell(id, fake);
      if (!shell) return;
      shell.body.innerHTML = block.html || '';
      shell.section.classList.add('section-custom');
      nodes.push(shell.section);
    });
    return nodes.length ? nodes : null;
  }

  /* ---------------------------------------------------------------- 联系我 */
  function renderContact() {
    var c = S.contact;
    if (!c) return null;
    var shell = sectionShell('contact', c);
    if (!shell) return null;

    var card = el('div', { class: 'card contact-card' });
    if (c.text) card.appendChild(el('p', { class: 'contact-text', text: c.text }));

    var actions = el('div', { class: 'contact-actions' });
    if (c.email) {
      actions.appendChild(el('a', { class: 'btn btn-primary', href: 'mailto:' + c.email, text: '✉ 发邮件给我' }));
      actions.appendChild(el('span', { class: 'contact-email', text: c.email }));
    }
    card.appendChild(actions);

    if (hasList(c.links)) {
      card.appendChild(el('ul', { class: 'link-list' }, c.links.map(function (link) {
        return el('li', {}, [
          el('a', { href: link.href, target: '_blank', rel: 'noopener', text: link.label + ' ↗' })
        ]);
      })));
    }
    if (c.note) card.appendChild(el('p', { class: 'contact-note', text: c.note }));

    shell.body.appendChild(card);
    return shell.section;
  }

  /* ---------------------------------------------------------------- 页脚 */
  function renderFooter() {
    var f = S.footer || {};
    var year = new Date().getFullYear();
    var footer = document.getElementById('siteFooter');
    if (!footer) return;
    var line = el('p', { class: 'footer-line' });
    line.appendChild(document.createTextNode('© ' + year + ' ' + (S.hero && S.hero.name ? S.hero.name : '') + ' · '));
    line.appendChild(document.createTextNode(f.text || ''));
    if (f.updated) line.appendChild(el('span', { class: 'footer-updated', text: '最后更新 ' + f.updated }));
    footer.appendChild(container([line]));
  }

  /* ---------------------------------------------------------------- 导航 */
  function renderNav() {
    var nav = document.getElementById('siteNav');
    if (!nav) return;
    RENDERED.forEach(function (item) {
      nav.appendChild(el('a', { class: 'nav-link', href: '#' + item.id, text: item.label }));
    });
  }

  /* ---------------------------------------------------------------- 行为 */
  function setupTheme() {
    var root = document.documentElement;
    var toggle = document.getElementById('themeToggle');
    var meta = document.querySelector('meta[name="theme-color"]');
    var icon = toggle ? toggle.querySelector('.theme-icon') : null;
    var preferred = S.theme && S.theme.default && S.theme.default !== 'auto' ? S.theme.default : null;
    var saved = null;
    try { saved = localStorage.getItem('site-theme'); } catch (e) { saved = null; }
    if (!saved && preferred) root.setAttribute('data-theme', preferred);

    function paint() {
      var dark = root.getAttribute('data-theme') !== 'light';
      if (icon) icon.textContent = dark ? '☀' : '☾';
      if (toggle) toggle.setAttribute('aria-label', dark ? '切换到亮色主题' : '切换到暗色主题');
      if (meta) meta.setAttribute('content', dark ? '#0b0d12' : '#f5f6fa');
    }

    if (toggle) {
      toggle.addEventListener('click', function () {
        var dark = root.getAttribute('data-theme') !== 'light';
        var next = dark ? 'light' : 'dark';
        root.setAttribute('data-theme', next);
        try { localStorage.setItem('site-theme', next); } catch (e) { /* 忽略 */ }
        paint();
      });
    }
    paint();
  }

  function setupMenu() {
    var toggle = document.getElementById('menuToggle');
    var nav = document.getElementById('siteNav');
    if (!toggle || !nav) return;
    toggle.addEventListener('click', function () {
      var open = nav.classList.toggle('is-open');
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
      toggle.setAttribute('aria-label', open ? '收起导航菜单' : '展开导航菜单');
    });
    nav.addEventListener('click', function (event) {
      if (event.target.closest('a')) {
        nav.classList.remove('is-open');
        toggle.setAttribute('aria-expanded', 'false');
      }
    });
  }

  function setupScroll() {
    var header = document.getElementById('siteHeader');
    var bar = document.getElementById('scrollProgress');
    var toTop = document.getElementById('toTop');

    function onScroll() {
      var doc = document.documentElement;
      var max = doc.scrollHeight - window.innerHeight;
      var ratio = max > 0 ? Math.min(1, Math.max(0, window.scrollY / max)) : 0;
      if (bar) bar.style.width = (ratio * 100).toFixed(2) + '%';
      if (header) header.classList.toggle('is-scrolled', window.scrollY > 8);
      if (toTop) toTop.hidden = window.scrollY < 480;
    }

    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    onScroll();

    if (toTop) {
      toTop.addEventListener('click', function () {
        window.scrollTo({ top: 0, behavior: prefersReducedMotion() ? 'auto' : 'smooth' });
      });
    }
  }

  function prefersReducedMotion() {
    return window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  }

  function setupReveal() {
    var nodes = document.querySelectorAll('.reveal');
    if (!nodes.length) return;
    if (!('IntersectionObserver' in window) || prefersReducedMotion()) {
      Array.prototype.forEach.call(nodes, function (node) { node.classList.add('is-visible'); });
      return;
    }
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      });
    }, { rootMargin: '0px 0px -10% 0px', threshold: 0.05 });
    Array.prototype.forEach.call(nodes, function (node) { observer.observe(node); });
  }

  function setupActiveNav() {
    if (!('IntersectionObserver' in window) || !RENDERED.length) return;
    var links = {};
    document.querySelectorAll('.nav-link').forEach(function (link) {
      links[link.getAttribute('href').slice(1)] = link;
    });
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        var link = links[entry.target.id];
        if (!link) return;
        if (entry.isIntersecting) {
          Object.keys(links).forEach(function (key) { links[key].classList.remove('is-active'); });
          link.classList.add('is-active');
        }
      });
    }, { rootMargin: '-45% 0px -50% 0px', threshold: 0 });
    RENDERED.forEach(function (item) {
      var section = document.getElementById(item.id);
      if (section) observer.observe(section);
    });
  }

  function setupLightbox() {
    var box = document.getElementById('lightbox');
    var img = document.getElementById('lightboxImg');
    var close = document.getElementById('lightboxClose');
    if (!box || !img) return;
    var lastFocus = null;

    function open(src, alt) {
      lastFocus = document.activeElement;
      img.setAttribute('src', src);
      img.setAttribute('alt', alt || '');
      box.hidden = false;
      document.body.classList.add('no-scroll');
      if (close) close.focus();
    }
    function hide() {
      box.hidden = true;
      img.removeAttribute('src');
      document.body.classList.remove('no-scroll');
      if (lastFocus && lastFocus.focus) lastFocus.focus();
    }

    document.querySelectorAll('.gallery-btn').forEach(function (button) {
      button.addEventListener('click', function () {
        var image = button.querySelector('img');
        if (image) open(image.getAttribute('src'), image.getAttribute('alt'));
      });
    });
    if (close) close.addEventListener('click', hide);
    box.addEventListener('click', function (event) { if (event.target === box) hide(); });
    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape' && !box.hidden) hide();
    });
  }

  /* ---------------------------------------------------------------- 跟随鼠标的光标特效 */
  function setupCursorFX() {
    var fx = document.getElementById('fx');
    if (!fx) return;
    var root = document.documentElement;
    var glow = fx.querySelector('.fx-glow');
    var ring = fx.querySelector('.fx-ring');
    var dot = fx.querySelector('.fx-dot');
    var fine = window.matchMedia && window.matchMedia('(pointer: fine)').matches;

    /* 系统里开了"减少动态效果"：只留一层很淡的网格，不做任何光标效果 */
    if (prefersReducedMotion()) {
      fx.classList.add('fx-reduced');
      return;
    }

    /* 触屏设备（手机/平板）没有鼠标指针：网格淡一些，手指按下去在按点处亮一下 */
    if (!fine) {
      fx.classList.add('fx-static');
      var pulseTimer = null;
      var pulseAt = function (x, y) {
        root.style.setProperty('--mx', x + 'px');
        root.style.setProperty('--my', y + 'px');
        [glow, ring, dot].forEach(function (node) {
          if (node) node.style.transform = 'translate3d(' + x + 'px,' + y + 'px,0)';
        });
        fx.classList.add('is-touch');
        window.clearTimeout(pulseTimer);
        pulseTimer = window.setTimeout(function () { fx.classList.remove('is-touch'); }, 900);
      };
      window.addEventListener('pointerdown', function (event) {
        pulseAt(event.clientX, event.clientY);
      }, { passive: true });
      window.addEventListener('touchstart', function (event) {
        var touch = event.touches && event.touches[0];
        if (touch) pulseAt(touch.clientX, touch.clientY);
      }, { passive: true });
      return;
    }

    var target = { x: window.innerWidth * 0.5, y: window.innerHeight * 0.34 };
    var glowPos = { x: target.x, y: target.y };
    var ringPos = { x: target.x, y: target.y };
    var idleTimer = null;

    function wake() {
      fx.classList.add('is-active');
      window.clearTimeout(idleTimer);
      idleTimer = window.setTimeout(function () { fx.classList.remove('is-active'); }, 2400);
    }

    window.addEventListener('pointermove', function (event) {
      if (event.pointerType === 'touch') return;
      target.x = event.clientX;
      target.y = event.clientY;
      root.style.setProperty('--mx', event.clientX + 'px');
      root.style.setProperty('--my', event.clientY + 'px');
      if (dot) dot.style.transform = 'translate3d(' + event.clientX + 'px,' + event.clientY + 'px,0)';
      var interactive = event.target && event.target.closest
        ? event.target.closest('a, button, input, textarea, select, label')
        : null;
      fx.classList.toggle('is-hover', !!interactive);
      wake();
    }, { passive: true });

    window.addEventListener('pointerdown', function () {
      fx.classList.add('is-click');
      window.setTimeout(function () { fx.classList.remove('is-click'); }, 280);
      wake();
    });

    document.addEventListener('mouseleave', function () {
      fx.classList.remove('is-active', 'is-hover');
    });

    (function loop() {
      glowPos.x += (target.x - glowPos.x) * 0.075;
      glowPos.y += (target.y - glowPos.y) * 0.075;
      ringPos.x += (target.x - ringPos.x) * 0.22;
      ringPos.y += (target.y - ringPos.y) * 0.22;
      if (glow) {
        glow.style.transform = 'translate3d(' + glowPos.x.toFixed(1) + 'px,' +
          glowPos.y.toFixed(1) + 'px,0)';
      }
      if (ring) {
        ring.style.transform = 'translate3d(' + ringPos.x.toFixed(1) + 'px,' +
          ringPos.y.toFixed(1) + 'px,0)';
      }
      window.requestAnimationFrame(loop);
    })();
  }

  function applyMeta() {
    var meta = S.meta || {};
    if (meta.title) {
      document.title = meta.title;
      var ogTitle = document.querySelector('meta[property="og:title"]');
      if (ogTitle) ogTitle.setAttribute('content', meta.title);
    }
    if (meta.description) {
      var desc = document.querySelector('meta[name="description"]');
      if (desc) desc.setAttribute('content', meta.description);
      var ogDesc = document.querySelector('meta[property="og:description"]');
      if (ogDesc) ogDesc.setAttribute('content', meta.description);
    }
    if (meta.brand) {
      var brand = document.getElementById('brandText');
      if (brand) brand.textContent = meta.brand;
    }
  }

  /* ---------------------------------------------------------------- 启动 */
  function render() {
    applyMeta();

    var app = document.getElementById('main');
    if (!app) return;

    var hero = renderHero();
    if (hero) app.appendChild(hero);

    [renderAbout(), renderLife(), renderSkills(), renderProjects(),
     renderTimeline(), renderGallery(), renderNow()]
      .forEach(function (section) { if (section) app.appendChild(section); });

    var custom = renderCustom();
    if (custom) {
      (Array.isArray(custom) ? custom : [custom]).forEach(function (section) {
        app.appendChild(section);
      });
    }

    var contact = renderContact();
    if (contact) app.appendChild(contact);

    renderNav();
    renderFooter();
    setupTheme();
    setupMenu();
    setupScroll();
    setupReveal();
    setupActiveNav();
    setupLightbox();
    setupCursorFX();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', render);
  } else {
    render();
  }
})();
