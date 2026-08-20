// Runtime compatibility layer for KIP CRM Pro.
// The CRM creates forms dynamically; this delegated submit handler guarantees
// those forms work even though their HTML is inserted with innerHTML.
window.addEventListener('load', function () {
  document.addEventListener('submit', function (event) {
    var form = event.target;
    if (!form || form.id !== 'recordForm') return;
    event.preventDefault();
    var title = (document.getElementById('modalTitle') || {}).textContent || '';
    var types = {
      'New Lead': 'lead', 'Edit Lead': 'lead',
      'New Contact': 'contact', 'New Account': 'account',
      'New Deal': 'deal', 'New Activity': 'activity',
      'New Campaign': 'campaign'
    };
    var type = types[title];
    if (type && typeof window.saveRecord === 'function') window.saveRecord(event, type);
  });
});
