(() => {
  // Lists the video addresses this reel page loaded: the sharpest picture
  // and the sound, one per line, or every address when the page does not
  // say which is which. Run on the reel's own page as a page script.
  const urls = [...new Set(performance.getEntriesByType('resource')
    .map(e => e.name).filter(n => n.includes('.mp4?'))
    .map(n => n.replace(/&bytestart=\d+&byteend=\d+/, '')))];
  if (!urls.length) return 'none yet';
  const tag = n => {
    try { return JSON.parse(atob(new URL(n).searchParams.get('efg'))); }
    catch (e) { return {}; }
  };
  const tagged = urls.every(n => typeof tag(n).vencode_tag === 'string');
  const best = sound => urls
    .filter(n => tag(n).vencode_tag.includes('audio') === sound)
    .sort((a, b) => (tag(b).bitrate || 0) - (tag(a).bitrate || 0))[0];
  const pic = tagged && best(false), snd = tagged && best(true);
  return (pic && snd ? [pic, snd] : urls)
    .map(n => n.replace(/&efg=[^&]*/, '')).join('\n');
})()
