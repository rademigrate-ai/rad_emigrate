import sys
import os
import json
import gzip
import hashlib
import urllib.parse
from pathlib import Path

# Ensure UTF-8 output
if sys.stdout.encoding.lower() != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

def normalize_url(u):
    if not u:
        return ""
    p = urllib.parse.urlsplit(u.strip())
    path = urllib.parse.unquote(p.path).rstrip('/')
    return urllib.parse.urlunsplit((p.scheme.lower(), p.netloc.lower(), path, p.query, ""))

def get_country_from_url_or_title(url, title, body_text):
    text = (url + " " + (title or "") + " " + (body_text or "")[:500]).lower()
    
    # Priority country keyword mapping
    mappings = [
        (['کانادا', 'canada', 'ساسکاچوان', 'نیوبرانزویک', 'ونکوور', 'تورنتو', 'کبک', 'مونترال'], 'CA'),
        (['استرالیا', 'australia', 'سیدنی', 'ملبورن', 'بریزبن'], 'AU'),
        (['آلمان', 'المان', 'germany', 'برلین', 'مونیخ', 'فرانکفورت'], 'DE'),
        (['انگلستان', 'انگلیس', 'بریتانیا', 'uk', 'united kingdom', 'لندن', 'منچستر'], 'GB'),
        (['آمریکا', 'امریکا', 'usa', 'united states', 'کالیفرنیا', 'نیویورک'], 'US'),
        (['فرانسه', 'france', 'پاریس', 'لیون'], 'FR'),
        (['ایتالیا', 'italy', 'رم', 'میلان'], 'IT'),
        (['اسپانیا', 'spain', 'مادرید', 'بارسلونا'], 'ES'),
        (['اتریش', 'austria', 'وین'], 'AT'),
        (['سوئیس', 'سوییس', 'switzerland', 'ژنو', 'زوریخ'], 'CH'),
        (['هلند', 'netherlands', 'آمستردام', 'روتردام'], 'NL'),
        (['ترکیه', 'turkey', 'استانبول', 'آنکارا'], 'TR'),
        (['یونان', 'greece', 'آتن'], 'GR'),
        (['پرتغال', 'portugal', 'لیسبون'], 'PT'),
        (['سوئد', 'sweden', 'استکهلم'], 'SE'),
        (['دانمارک', 'denmark', 'کپنهاگ'], 'DK'),
        (['فنلاند', 'finland', 'هلسینکی'], 'FI'),
        (['نروژ', 'norway', 'اسلو'], 'NO'),
        (['بلژیک', 'belgium', 'بروکسل'], 'BE'),
        (['ارمنستان', 'armenia', 'ایروان'], 'AM'),
        (['آفریقای جنوبی', 'آفریقای-جنوبی', 'south africa', 'کیپ تاون', 'ژوهانسبورگ'], 'ZA'),
        (['نیوزلند', 'نیوزیلند', 'new zealand', 'اوکلند'], 'NZ'),
        (['مجارستان', 'hungary', 'بوداپست'], 'HU'),
        (['قبرس', 'cyprus'], 'CY'),
        (['روسیه', 'russia', 'مسکو'], 'RU'),
        (['چین', 'china', 'پکن', 'شانگهای'], 'CN'),
        (['لهستان', 'poland', 'ورشو'], 'PL'),
        (['مالزی', 'malaysia', 'کوالالامپور'], 'MY'),
        (['امارات', 'دبی', 'دوبی', 'uae', 'ابوظبی'], 'AE'),
        (['گرجستان', 'georgia', 'تفلیس'], 'GE'),
        (['سنگاپور', 'singapore'], 'SG'),
        (['هند', 'india', 'دهلی', 'بمبئی'], 'IN'),
        (['ژاپن', 'japan', 'توکیو'], 'JP'),
        (['اسلواکی', 'slovakia', 'براتیسلاوا'], 'SK'),
        (['آرژانتین', 'argentina', 'بوئنوس آیرس'], 'AR'),
        (['برزیل', 'brazil', 'برازیلیا'], 'BR'),
        (['کرواسی', 'croatia', 'زاگرب'], 'HR'),
        (['چک', 'جمهوری چک', 'czech', 'پراگ'], 'CZ'),
        (['ایرلند', 'ireland', 'دوبلین'], 'IE'),
        (['مکزیک', 'mexico'], 'MX'),
        (['اکوادور', 'ecuador'], 'EC'),
        (['اوکراین', 'ukraine', 'کیف'], 'UA'),
        (['ایران', 'iran', 'تهران'], 'IR')
    ]
    
    # 1. Match from URL first
    u_dec = urllib.parse.unquote(url).lower()
    for keys, code in mappings:
        for k in keys:
            if k in u_dec:
                return code
                
    # 2. Match from title
    t_dec = (title or "").lower()
    for keys, code in mappings:
        for k in keys:
            if k in t_dec:
                return code
                
    # 3. Match from initial body text
    b_dec = (body_text or "")[:300].lower()
    for keys, code in mappings:
        for k in keys:
            if k in b_dec:
                return code
                
    return None

def is_pathway_themed(title, body_text):
    keywords = [
        'ویزا', 'ویزای', 'اقامت', 'مهاجرت', 'تحصیل', 'تحصیلی', 'کار', 'کاری',
        'سرمایه گذاری', 'ثبت شرکت', 'ازدواج', 'تولد', 'تمکن مالی', 'پناهندگی',
        'جاب آفر', 'اکسپرس اینتری', 'اسکیل ورکر', 'شنگن', 'شینگن', 'پاسپورت'
    ]
    combined = ((title or "") + " " + (body_text or "")[:400]).lower()
    return any(k in combined for k in keywords)

print("Starting comprehensive source reconciliation...")

# 1. Load Codex baseline and inaccessible register
root = Path('.')
audit_dir = root / '_audit/RAD_CONTENT_COMPLETION_20261027'
with open(audit_dir / 'inaccessible-source-list.json', 'r', encoding='utf-8') as f:
    inaccessible_list = json.load(f)

inaccessible_by_url = {normalize_url(item['url']): item for item in inaccessible_list}
print(f"Loaded inaccessible register: {len(inaccessible_by_url)} URLs")

# 2. Load Antigravity recovered articles
antigravity_recovered = {}
with gzip.open('_scratch/recovered_radmohajer_articles.jsonl.gz', 'rt', encoding='utf-8') as f:
    for line in f:
        data = json.loads(line)
        norm = normalize_url(data.get('url'))
        if norm not in antigravity_recovered or len(data.get('body_text', '')) > len(antigravity_recovered[norm].get('body_text', '')):
            antigravity_recovered[norm] = data

print(f"Loaded Antigravity unique recoveries: {len(antigravity_recovered)} URLs")

# 3. Load Codex prepared canonical & other-titles inventories
with open(audit_dir / 'prepared/canonical-page-inventory.json', 'r', encoding='utf-8') as f:
    canonical_pages = json.load(f)
with open(audit_dir / 'prepared/other-titles-inventory.json', 'r', encoding='utf-8') as f:
    existing_other_titles = json.load(f)

print(f"Codex baseline: {len(canonical_pages)} canonical pages, {len(existing_other_titles)} other-titles articles")

# 4. Reconcile Antigravity recoveries
substantive_recoveries = []
empty_recoveries = []
exact_overlaps = []
conflicts = []

grok_100_frontier = set(inaccessible_by_url.keys())

for norm_u, rec in antigravity_recovered.items():
    blks = rec.get('blocks', [])
    b_len = rec.get('body_text_len', 0)
    title = rec.get('title')
    body = rec.get('body_text', '')
    
    if len(blks) == 0 or b_len == 0:
        empty_recoveries.append({
            'url': rec['url'],
            'normalized_url': norm_u,
            'title': title,
            'reason': 'Archive or category listing without standalone article body'
        })
        continue
        
    country = get_country_from_url_or_title(rec['url'], title, body)
    pathway = is_pathway_themed(title, body)
    
    record = {
        'url': rec['url'],
        'normalized_url': norm_u,
        'title': title,
        'country_code': country,
        'blocks_count': len(blks),
        'body_text_len': b_len,
        'source_type': rec.get('source_type'),
        'raw_sha256': rec.get('raw_sha256'),
        'is_pathway_themed': pathway,
        'human_review_required': pathway,
        'pathway_review_flag': "mohajer_independent_visa_pathway_review" if pathway else None,
        'destination': "other_titles",
        'destination_section': "دیگر عناوین / Other Titles",
        'blocks': blks,
        'body_text': body
    }
    substantive_recoveries.append(record)

print(f"Substantive recovered articles: {len(substantive_recoveries)}")
print(f"Empty / listing pages: {len(empty_recoveries)}")

# 5. Cross-reference against 422 inaccessible register
recovered_from_inaccessible = [r for r in substantive_recoveries if r['normalized_url'] in inaccessible_by_url]
truly_unresolved = []

for norm_u, item in inaccessible_by_url.items():
    if norm_u not in antigravity_recovered or len(antigravity_recovered[norm_u].get('blocks', [])) == 0:
        # Determine exact blocker
        err = item.get('reason') or item.get('error') or item.get('status')
        truly_unresolved.append({
            'url': item['url'],
            'normalized_url': norm_u,
            'title': item.get('title'),
            'category': item.get('category'),
            'blocker_type': 'HTTP_403_OR_404_NO_ARCHIVE' if ('403' in str(err) or '404' in str(err)) else 'LIVE_HOST_FIREWALL_NO_SNAPSHOT',
            'detail': str(err)
        })

print(f"Recovered from previously blocked register: {len(recovered_from_inaccessible)}")
print(f"Truly unresolved items: {len(truly_unresolved)}")

# 6. Human editorial review queue
review_queue = [r for r in substantive_recoveries if r['human_review_required']]
print(f"Human editorial review queue (pathway-themed): {len(review_queue)} articles")

# 7. Country distribution for recovered substantive articles
country_dist = {}
for r in substantive_recoveries:
    c = r['country_code'] or 'GLOBAL'
    country_dist[c] = country_dist.get(c, 0) + 1

# 8. Save all output artifacts
out_reconciliation = {
    'summary': {
        'total_inaccessible_register_examined': len(inaccessible_by_url),
        'total_antigravity_recovered_unique_urls': len(antigravity_recovered),
        'total_substantive_recovered_articles': len(substantive_recoveries),
        'total_empty_or_listing_pages': len(empty_recoveries),
        'total_recovered_from_inaccessible_register': len(recovered_from_inaccessible),
        'total_truly_unresolved': len(truly_unresolved),
        'total_human_editorial_review_required': len(review_queue),
        'total_characters_recovered': sum(r['body_text_len'] for r in substantive_recoveries)
    },
    'country_distribution': country_dist,
    'truly_unresolved_breakdown': {
        'HTTP_403_OR_404_NO_ARCHIVE': sum(1 for u in truly_unresolved if u['blocker_type'] == 'HTTP_403_OR_404_NO_ARCHIVE'),
        'LIVE_HOST_FIREWALL_NO_SNAPSHOT': sum(1 for u in truly_unresolved if u['blocker_type'] == 'LIVE_HOST_FIREWALL_NO_SNAPSHOT')
    }
}

with open(audit_dir / 'source_reconciliation_report.json', 'w', encoding='utf-8') as f:
    json.dump(out_reconciliation, f, indent=2, ensure_ascii=False)

# Save destination mapping manifest (without the huge blocks to keep file lightweight)
lightweight_mapping = []
for r in substantive_recoveries:
    m = {k: v for k, v in r.items() if k not in ('blocks', 'body_text')}
    lightweight_mapping.append(m)

with open(audit_dir / 'complete_source_destination_map.json', 'w', encoding='utf-8') as f:
    json.dump(lightweight_mapping, f, indent=2, ensure_ascii=False)

with open(audit_dir / 'human_editorial_review_queue.json', 'w', encoding='utf-8') as f:
    json.dump(review_queue, f, indent=2, ensure_ascii=False)

with open(audit_dir / 'truly_unresolved_sources.json', 'w', encoding='utf-8') as f:
    json.dump(truly_unresolved, f, indent=2, ensure_ascii=False)

print("\nRECONCILIATION COMPLETE!")
print(f"Report: {audit_dir / 'source_reconciliation_report.json'}")
print(f"Destination Map: {audit_dir / 'complete_source_destination_map.json'}")
print(f"Review Queue: {audit_dir / 'human_editorial_review_queue.json'}")
print(f"Unresolved Sources: {audit_dir / 'truly_unresolved_sources.json'}")

