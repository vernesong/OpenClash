// Extracted from luasrc/view/openclash/oixcloud.htm - edit this file, not the template.
// <%:...%> markers and <%=...%> islands are rendered server-side by the translate_js action.

//<![CDATA[
  var oix_plan = document.getElementById('oix-plan');
  var oixFields = {
    plan: oix_plan,
    plan_time: document.getElementById('oix-plantime'),
    money: document.getElementById('oix-money'),
    aff_money: document.getElementById('oix-affmoney'),
    today_used: document.getElementById('oix-today-used'),
    used: document.getElementById('oix-used'),
    unused: document.getElementById('oix-unused'),
    traffic: document.getElementById('oix-traffic'),
    integral: document.getElementById('oix-integral')
  };
  var obj = document.getElementById("additional");
  var oix_it = document.getElementById("oix_it");
  var oix_container = document.getElementById("oix-announcement");
  var oix_banner = document.getElementById("oix-announcement-banner");
  var oix_content = document.getElementById("oix-announcement-content");
  var showmore=1;

  document.addEventListener('DOMContentLoaded', function() {
      DarkModeDetector.init();
      obj.classList.remove('collapsed');
      obj.classList.add('expanded');
  });

  // open the cover on its own; slow or failed data requests must not trap the card
  setTimeout(collapseCard, 2000);

  var oixPollTimer = null;
  var oixInfoRequest = 0;
  var announcementShown = false;

  function renderOixFields(info) {
    Object.keys(oixFields).forEach(function(key) {
      var field = oixFields[key];
      var value = info && info[key] != null ? String(info[key]) : '';
      field.textContent = value;
      if (key !== 'plan') field.title = value;
    });
  }

  function oixPollRefresh() {
    var request = ++oixInfoRequest;
    XHR.get('<%=luci.dispatcher.build_url("admin", "services", "openclash", "oix_info")%>', null, function(x, status) {
      if (request !== oixInfoRequest) return;
      if (x && x.status === 200 && status && status.result && typeof status.result === 'object') {
        renderOixFields(status.result);
        if (!announcementShown && status.result.announcement) {
          announcementShown = true;
          loadOixAnnouncement(status.result.announcement);
        }
        if (showmore) collapseCard();
        else expandCard();
      } else {
        if (status && status.code === 'auth') {
          renderOixFields(null);
          oix_plan.classList.remove('oc-hidden');
          oix_container.classList.add('oc-hidden');
        }
        expandCard();
      }
    });
  }

  oixPollRefresh();

  function startOixPoll() {
    if (oixPollTimer) return;
    oixPollTimer = setInterval(oixPollRefresh, 60000);
  }

  function stopOixPoll() {
    if (oixPollTimer) {
      clearInterval(oixPollTimer);
      oixPollTimer = null;
    }
  }

  document.addEventListener('visibilitychange', function() {
    if (document.hidden) {
      stopOixPoll();
    } else {
      startOixPoll();
      oixPollRefresh();
    }
  });

  startOixPoll();
  if (document.hidden) stopOixPoll();

  function loadOixAnnouncement(announcement) {
    if (!oix_container || !oix_banner || !oix_content) return;

    var content = window.OCMarkdown && OCMarkdown.announcementContent &&
        OCMarkdown.announcementContent(announcement);
    if (!content) return;
    content.querySelectorAll('br, img').forEach(function(node) {
        node.replaceWith(document.createTextNode(node.alt || ' '));
    });
    var result = Array.prototype.map.call(content.childNodes, function(node) {
        return node.textContent;
    }).join(' ').replace(/\s+/g, ' ').trim();

    if (!result) {
        oix_container.classList.add('oc-hidden');
        return;
    }

    if (announcement.date) result = announcement.date + ': ' + result;
    oix_plan.classList.add('oc-hidden');
    oix_container.classList.remove('oc-hidden');

    var oixAnimator = new AnnouncementAnimator({
        bannerElement: oix_banner,
        contentElement: oix_content,
        announcements: [result],
        isRandomTips: false,
        loopDelay: 2000,
    });

    oixAnimator.init();

    window.addEventListener('beforeunload', function() {
        oixAnimator.destroy();
    });

    setTimeout(function() {
        oix_plan.classList.remove('oc-hidden');
        oix_container.classList.add('oc-hidden');
        oixAnimator.destroy();
    }, 1000 * 60);
  }

  function oix_checkin_btn(btn)
  {
    if (btn && btn.disabled) return;
    if (btn) btn.disabled = true;
    XHR.get('<%=luci.dispatcher.build_url("admin", "services", "openclash", "oix_checkin")%>', null, function(x, status) {
      if (btn) btn.disabled = false;
      if (x && x.status === 200 && status && status.result && typeof status.result === 'object') {
        if (status.result.ret == 200 && status.result.data) {
          ocToast("<%:oixCloud Checkin Successful, Result:%> " + status.result.data.checkin, 'success');
          oixPollRefresh();
        }
        else if (status.result.msg) {
          ocToast("<%:oixCloud Checkin Failed, Result:%> " + status.result.msg, 'error');
          if (status.code === 'auth') oixPollRefresh();
        }
        else {
          ocToast("<%:oixCloud Checkin Failed! Please Check And Try Again...%>", 'error');
        }
      }
      else {
        ocToast("<%:oixCloud Checkin Failed! Please Check And Try Again...%>", 'error');
      }
    });
  }

  function web_oix()
  {
    window.open('https://oixcloud.com/');
  }

  function show_more()
  {
    if (obj.classList.contains('expanded')) {
      collapseCard();
      showmore = 1;
    }
    else {
      if (oix_plan.textContent != "") {
        expandCard();
        showmore = 0;
      }
      else {
        web_oix();
      }
    }
  }

  function randomizeSlogan()
  {
    var rdmdl = Math.floor(Math.random() * 6) + 1;
    if (rdmdl == 1) {
      oix_it.innerHTML = '<%:Simple & trustworthy%>';
    }
    if (rdmdl == 2) {
      oix_it.innerHTML = '<%:Cross-platform Support%>';
    }
    if (rdmdl == 3) {
      oix_it.innerHTML = '<%:Global Acceleration Network%>';
    }
    if (rdmdl == 4) {
      oix_it.innerHTML = '<%:Easy to Use%>';
    }
    if (rdmdl == 5) {
      oix_it.innerHTML = '<%:Intelligent Shunting%>';
    }
    if (rdmdl == 6) {
      oix_it.innerHTML = '<%:Perfect Technical Support%>';
    }
  }

  function expandCard()
  {
    var wasExpanded = obj.classList.contains('expanded');
    if (!wasExpanded) {
      obj.classList.add('expanded');
      obj.classList.remove('collapsed');
      randomizeSlogan();
    }
  }

  function collapseCard()
  {
    if (!obj.classList.contains('collapsed')) {
      obj.classList.add('collapsed');
      obj.classList.remove('expanded');
    }
  }

//]]>
