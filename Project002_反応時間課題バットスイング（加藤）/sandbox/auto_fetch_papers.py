import re
import os
import urllib.request
import json

try:
    import pypdf
    PdfReader = pypdf.PdfReader
except ImportError:
    import PyPDF2
    PdfReader = PyPDF2.PdfReader

def download_file(url, filepath):
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=15) as response:
            if response.status == 200 and 'application/pdf' in response.headers.get('Content-Type', '').lower():
                with open(filepath, 'wb') as f:
                    f.write(response.read())
                return True
    except Exception as e:
        pass
    return False

def get_oa_pdf_url(doi):
    if not doi:
        return None
    try:
        api_url = f"https://api.unpaywall.org/v2/{doi}?email=bot@example.com"
        req = urllib.request.Request(api_url)
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status == 200:
                data = json.loads(response.read().decode('utf-8'))
                if data.get('is_oa') and data.get('best_oa_location'):
                    return data['best_oa_location'].get('url_for_pdf')
    except:
        pass
    return None

pdf_path = "../References/Qualysis_AIM_マーカー貼付参考文献/先行研究一覧_Qualisys_AIM_バッティング研究.pdf"
out_dir = "../References/Qualysis_AIM_マーカー貼付参考文献"

pdf = PdfReader(pdf_path)
text = '\n'.join([page.extract_text() for page in pdf.pages])

papers = []
current_paper = {}

lines = text.split('\n')
for i, line in enumerate(lines):
    line = line.strip()
    if not line:
        continue
    
    # Match paper start (e.g. "1 Title of the paper")
    m_title = re.match(r'^(\d+)\s+(.+)', line)
    if m_title and '著者' not in line and '要旨' not in line:
        num = int(m_title.group(1))
        # Valid paper numbers are 1 to 32
        if 0 < num <= 32:
            if current_paper and 'title' in current_paper:
                papers.append(current_paper)
            current_paper = {'num': num, 'title': m_title.group(2).strip(), 'authors': '', 'year': '', 'abstract': '', 'url': '', 'doi': ''}
            continue
    
    if not current_paper:
        continue
        
    if line.startswith('著者 '):
        current_paper['authors'] = line[3:].strip()
        m_year = re.search(r'\((\d{4})\)', current_paper['authors'])
        if m_year:
            current_paper['year'] = m_year.group(1)
    elif line.startswith('要旨 '):
        current_paper['abstract'] += line[3:].strip() + " "
    elif line.startswith('情報 '):
        current_paper['info'] = line[3:].strip()
    elif line.startswith('URL:') or line.startswith('URL :'):
        current_paper['url'] = line[4:].strip()
    elif 'doi.org/' in line:
        m_doi = re.search(r'doi\.org/(10\.\d{4,9}/[-._;()/:A-Z0-9]+)', line, re.I)
        if m_doi:
            current_paper['doi'] = m_doi.group(1)
        if not current_paper.get('url'):
            current_paper['url'] = line.strip()
    else:
        if current_paper.get('abstract') and 'info' not in current_paper:
            current_paper['abstract'] += line + " "

if current_paper and 'title' in current_paper:
    papers.append(current_paper)

print(f"Found {len(papers)} papers.")

start_index = 8
success_count = 0

for p in papers:
    num = p['num']
    title = p['title']
    authors = p['authors']
    year = p['year']
    abstract = p.get('abstract', '').strip()
    url = p.get('url', '')
    doi = p.get('doi', '')
    
    first_author = "Author"
    m_author = re.match(r'^([^,]+)', authors)
    if m_author:
        first_author = m_author.group(1).replace(' ', '')
    
    folder_idx = start_index + num - 1
    folder_name = f"{folder_idx:02d}_{first_author}_et_al_{year}"
    folder_path = os.path.join(out_dir, folder_name)
    os.makedirs(folder_path, exist_ok=True)
    
    pdf_downloaded = False
    safe_title = re.sub(r'[^A-Za-z0-9]', '_', title[:30])
    pdf_filename = f"01_{safe_title}.pdf"
    pdf_filepath = os.path.join(folder_path, pdf_filename)
    
    # Try finding PDF
    if doi:
        oa_url = get_oa_pdf_url(doi)
        if oa_url:
            pdf_downloaded = download_file(oa_url, pdf_filepath)
    
    if not pdf_downloaded and url and 'pdf' in url.lower():
        pdf_downloaded = download_file(url, pdf_filepath)
        
    if pdf_downloaded:
        success_count += 1
        print(f"[{folder_name}] PDF Downloaded successfully.")
    else:
        print(f"[{folder_name}] Could not download PDF.")
        
    notes_path = os.path.join(folder_path, "03_notes.md")
    with open(notes_path, "w", encoding="utf-8") as f:
        f.write(f"# 論文メモ: {first_author} et al. ({year})\n\n")
        f.write("## 文献情報\n")
        f.write(f"- **タイトル**: {title}\n")
        f.write(f"- **著者**: {authors}\n")
        f.write(f"- **発行年**: {year}\n")
        f.write(f"- **URL/DOI**: {url}\n\n")
        f.write("## 概要\n")
        f.write(f"{abstract}\n\n")
        f.write("## 大事な部分・要点\n")
        f.write("(その論文が主に述べていること・主張・結論を簡潔な箇条書きで示してください)\n")
        f.write("- \n- \n\n")
        f.write("## 自身のプロジェクトへの応用・検証したいこと\n")
        f.write("- \n")

print(f"Completed! {success_count}/{len(papers)} PDFs downloaded.")
