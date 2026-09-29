#!/usr/bin/env python3
"""Extract the tabular 1-6500 PDF into importable JSON plus font-aware legacy segments.

The PDF mixes Kruti Dev legacy Hindi and Unicode fonts. This script does not
transliterate Kruti Dev itself; instead it records per-span `legacy` flags so
the Flutter importer can convert only the legacy spans without corrupting
Unicode punctuation / English text.
"""
from __future__ import annotations
import argparse, json, re
from pathlib import Path
import fitz

TEMPLATES = [
 (1,50,(35.8,71.2,206.0,276.9,347.8,411.4,468.3)),
 (51,77,(40.4,68.8,203.6,295.8,373.8,451.7,501.3)),
 (78,105,(42.8,71.2,205.9,298.1,376.0,453.8,503.6)),
 (106,125,(49.9,78.3,213.1,305.2,383.2,461.0,510.8)),
 (126,136,(52.0,80.3,215.0,307.1,385.1,463.2,512.9)),
 (137,161,(49.9,78.3,213.1,305.2,383.2,461.0,510.8)),
 (162,199,(42.8,71.2,206.0,298.1,376.0,453.9,503.7)),
 (200,238,(43.3,71.7,206.4,298.6,376.6,454.4,504.2)),
 (239,269,(50.4,78.7,213.5,305.7,383.7,461.5,511.3)),
 (270,300,(42.8,71.2,206.0,298.1,376.0,453.9,503.7)),
 (301,337,(86.4,114.8,249.6,341.8,419.6,497.5,547.2)),
]
ANSWER = {'1':'A','2':'B','3':'C','4':'D'}

def template(page_no):
    for start,end,value in TEMPLATES:
        if start <= page_no <= end:
            return value
    raise ValueError(f'No layout template for page {page_no}')

def page_spans(page):
    out=[]
    data=page.get_text('dict')
    for bi,block in enumerate(data.get('blocks', [])):
        for li,line in enumerate(block.get('lines', [])):
            for si,span in enumerate(line.get('spans', [])):
                text=span.get('text','')
                if not text: continue
                x0,y0,x1,y1=span['bbox']
                out.append({
                    'x0':x0,'y0':y0,'x1':x1,'y1':y1,'text':text,
                    'font':span.get('font',''),'block':bi,'line':li,'span':si,
                })
    return out

def normalize_space(text):
    return re.sub(r'\s+', ' ', text).strip()

def join_cell(spans):
    if not spans:
        return '', []
    groups={}
    for s in spans:
        groups.setdefault((s['block'],s['line']), []).append(s)
    lines=[]
    for vals in groups.values():
        vals.sort(key=lambda s:(s['x0'],s['span']))
        lines.append((min(s['y0'] for s in vals),min(s['x0'] for s in vals),vals))
    lines.sort(key=lambda x:(x[0],x[1]))

    parts=[]
    for line_index,(_,__,vals) in enumerate(lines):
        if line_index: parts.append({'text':' ','legacy':False})
        for s in vals:
            legacy='Kruti' in s['font']
            text=s['text']
            if parts and parts[-1]['legacy']==legacy:
                parts[-1]['text'] += text
            else:
                parts.append({'text':text,'legacy':legacy})
    raw=normalize_space(''.join(p['text'] for p in parts))
    cleaned=[]
    for p in parts:
        text=re.sub(r'\s+', ' ', p['text'])
        if not text: continue
        if cleaned and cleaned[-1]['legacy']==p['legacy']:
            cleaned[-1]['text'] += text
        else:
            cleaned.append({'text':text,'legacy':p['legacy']})
    return raw, cleaned

def classify(raw):
    # Classification is source-explicit only; it does not infer a statute.
    if 'Hkkjrh; ukxfjd lqj{kk lafgrk' in raw or 'ch,u,l,l' in raw:
        return 'BNSS'
    if 'Hkkjrh; U;k; lafgrk' in raw or re.search(r'ch,u,l(?!,l)', raw):
        return 'BNS'
    if 'Hkkjrh; lk{; vf/kfu;e' in raw:
        return 'BSA'
    if re.search(r'ih[0-9.]*ih[0-9.]*vkj|ihihvkj', raw, re.I):
        return 'PPR'
    return 'Other'

def extract(pdf_path):
    doc=fitz.open(pdf_path)
    rows=[]; current=None
    for pno,page in enumerate(doc,1):
        starts=template(pno); qx0=starts[0]
        spans=page_spans(page)
        # Word extraction preserves question-number anchors consistently across
        # the PDF's many font subsets; cells are then reconstructed from spans.
        anchors=[]
        for w in page.get_text('words'):
            token=(w[4] or '').strip()
            if abs(w[0]-qx0)<=8 and re.fullmatch(r'\d{1,4}',token):
                n=int(token)
                if 1<=n<=6500:
                    anchors.append((w[1],n))
        anchors.sort(key=lambda x:(x[0],x[1]))

        def split(row_spans):
            _,qx,ax,bx,cx,dx,rx=starts
            ranges={'question':(qx,ax),'A':(ax,bx),'B':(bx,cx),'C':(cx,dx),'D':(dx,rx),'correct':(rx,999)}
            out={}
            for key,(lo,hi) in ranges.items():
                selected=[s for s in row_spans if lo-.25<=s['x0']<hi-.25]
                out[key]=join_cell(selected)
            return out

        if current is not None:
            lead_end=(anchors[0][0]-5) if anchors else page.rect.height
            lead=[s for s in spans if s['y0']<lead_end]
            more=split(lead)
            for key,(raw,segs) in more.items():
                if not raw: continue
                current[key]['raw']=normalize_space(current[key]['raw']+' '+raw)
                if current[key]['segments'] and segs:
                    current[key]['segments'].append({'text':' ','legacy':False})
                current[key]['segments'].extend(segs)

        for i,(y,n) in enumerate(anchors):
            if current is not None:
                rows.append(current)
            y2=(anchors[i+1][0]-5) if i+1<len(anchors) else page.rect.height
            row_spans=[s for s in spans if y-5<=s['y0']<y2]
            cells=split(row_spans)
            current={'id':n,'page':pno}
            for key,(raw,segs) in cells.items():
                current[key]={'raw':raw,'segments':segs}
    if current is not None:
        rows.append(current)

    by_id={}
    for row in rows:
        by_id.setdefault(row['id'],row)
    return [by_id[k] for k in sorted(by_id)]

def to_import_row(row,pdf_name):
    q=row['question']['raw']; opts={k:row[k]['raw'] for k in 'ABCD'}
    correct_match=re.search(r'[1-4]',row['correct']['raw'])
    answer=ANSWER.get(correct_match.group(0)) if correct_match else None
    all_raw=' '.join([q,*opts.values()])
    topic=classify(all_raw)
    return {
        'id':row['id'],
        'topic':topic,
        'question':q,
        'options':opts,
        'answer':answer,
        'explanation':f'Source answer key: option {answer}.' if answer else '',
        'difficulty':'medium',
        'source':f'{pdf_name}, page {row["page"]}',
        'legacy_segments':{
            'question':row['question']['segments'],
            'options':{k:row[k]['segments'] for k in 'ABCD'},
        },
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('pdf')
    ap.add_argument('--out',default='question_bank_extracted.json')
    ap.add_argument('--topic',choices=['BNS','BNSS','BSA','PPR','Other','ALL'],default='ALL')
    ap.add_argument('--report',default='extraction_report.json')
    args=ap.parse_args()
    rows=extract(args.pdf)
    import_rows=[to_import_row(r,Path(args.pdf).name) for r in rows]
    missing=[i for i in range(1,6501) if i not in {r['id'] for r in rows}]
    nonimportable=[r['id'] for r in import_rows if not r['answer'] or not r['question'] or any(not r['options'][k] for k in 'ABCD')]
    selected=[r for r in import_rows if r['id'] not in nonimportable and (args.topic=='ALL' or r['topic']==args.topic)]
    Path(args.out).write_text(json.dumps(selected,ensure_ascii=False,indent=2),encoding='utf-8')
    counts={name:sum(1 for r in import_rows if r['topic']==name) for name in ['BNS','BNSS','BSA','PPR','Other']}
    report={'numbered_rows':len(rows),'missing_ids':missing,'nonimportable_ids':nonimportable,'topic_counts_explicit':counts,'written':len(selected),'topic_filter':args.topic}
    Path(args.report).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))

if __name__=='__main__':
    main()
