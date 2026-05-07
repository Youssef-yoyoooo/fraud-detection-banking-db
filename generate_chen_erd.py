"""
Generate a compact Chen-notation ERD for the Fraud Detection Banking Database.
Uses Graphviz (neato) with tight, manually tuned positions.
"""

import graphviz
import os

OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))


def create_chen_erd():
    dot = graphviz.Graph(
        'FraudDetectionERD',
        format='png',
        engine='neato',
        graph_attr={
            'overlap': 'false',
            'splines': 'true',
            'sep': '+8',
            'bgcolor': 'white',
            'dpi': '200',
            'fontname': 'Arial',
            'pad': '0.3',
            'nodesep': '0.4',
            'ranksep': '0.4',
            'margin': '0',
        },
        node_attr={
            'fontname': 'Arial',
            'fontsize': '9',
            'margin': '0.04,0.02',
        },
        edge_attr={
            'fontname': 'Arial',
            'fontsize': '8',
            'color': '#666666',
            'penwidth': '1.0',
        }
    )

    # ── Colors ──
    ENT_FILL   = '#3B7DD8'
    ENT_FONT   = 'white'
    PK_FILL    = '#FFF3CD'
    PK_BORDER  = '#D4A017'
    AT_FILL    = '#EDF2FB'
    AT_BORDER  = '#9DB8D8'
    REL_FILL   = '#E8F5E9'
    REL_BORDER = '#43A047'
    WEAK_FILL  = '#FFE0B2'
    WEAK_BDR   = '#EF6C00'

    # ── Helpers ──
    def ent(name, pos, weak=False):
        dot.node(name, name, shape='box', style='filled,bold',
                 fillcolor=WEAK_FILL if weak else ENT_FILL,
                 fontcolor='#333' if weak else ENT_FONT,
                 color=WEAK_BDR if weak else ENT_FILL,
                 penwidth='2.0', width='1.4', height='0.5',
                 pos=pos, fontsize='11')

    def pk(entity, attr, pos):
        nid = f"{entity}_{attr}"
        dot.node(nid, f'<<U>{attr}</U>>', shape='ellipse', style='filled',
                 fillcolor=PK_FILL, color=PK_BORDER,
                 penwidth='1.5', width='0.85', height='0.32',
                 pos=pos, fontsize='7.5')
        dot.edge(entity, nid, penwidth='0.8')

    def at(entity, attr, pos, unique=False):
        nid = f"{entity}_{attr}"
        lab = f'<<U>{attr}</U>>' if unique else attr
        dot.node(nid, lab, shape='ellipse', style='filled',
                 fillcolor=AT_FILL, color=PK_BORDER if unique else AT_BORDER,
                 penwidth='1.2' if unique else '0.8',
                 width='0.8', height='0.3',
                 pos=pos, fontsize='7.5')
        dot.edge(entity, nid, penwidth='0.7')

    def rel(rid, label, pos):
        dot.node(rid, label, shape='diamond', style='filled',
                 fillcolor=REL_FILL, color=REL_BORDER,
                 penwidth='1.5', width='1.2', height='0.75',
                 pos=pos, fontsize='9')

    def link(rid, entity, card):
        dot.edge(rid, entity, label=f' {card} ',
                 penwidth='1.2', fontsize='9', fontcolor='#C62828')

    # ==========================================================
    #  LAYOUT — 3-layer grid, tightly packed
    #  Row 1 (y=10): Branches, Customers
    #  Row 2 (y=7):  Accounts
    #  Row 3 (y=4.5):Transactions, FlaggedAccounts
    #  Row 4 (y=2):  FraudRules, FraudAlerts, FraudReports
    #  Sidebar (right): Users, AuditLog, LoginAttempts
    # ==========================================================

    # ── Row 1: Core ──
    ent('Branches',   '0,10!')
    ent('Customers',  '7,10!')

    # ── Row 2: Accounts ──
    ent('Accounts',   '3.5,7!')

    # ── Row 3: Transactions + Flagged ──
    ent('Transactions', '3.5,4!')
    ent('FlaggedAccounts', '8.5,6!', weak=True)

    # ── Row 4: Fraud pipeline ──
    ent('FraudRules',   '0,1!')
    ent('FraudAlerts',  '3.5,1!')
    ent('FraudReports', '7,1!')

    # ── Sidebar: Users & Security ──
    ent('Users',         '11.5,4!')
    ent('AuditLog',      '11.5,1!', weak=True)
    ent('LoginAttempts', '14.5,2.5!', weak=True)

    # ==========================================================
    #  PRIMARY KEYS
    # ==========================================================
    pk('Branches',        'branch_id',      '-1.8,11!')
    pk('Customers',       'customer_id',    '8.8,11!')
    pk('Accounts',        'account_id',     '2,8.2!')
    pk('Transactions',    'transaction_id', '1.8,5!')
    pk('FraudRules',      'rule_id',        '-1.8,2!')
    pk('FraudAlerts',     'alert_id',       '2,2!')
    pk('FraudReports',    'report_id',      '7,2.3!')
    pk('FlaggedAccounts', 'flag_id',        '10.2,7!')
    pk('Users',           'user_id',        '13.3,5!')
    pk('AuditLog',        'log_id',         '13.3,1.5!')
    pk('LoginAttempts',   'attempt_id',     '16.3,3.2!')

    # ==========================================================
    #  ATTRIBUTES (compact — only most important ones)
    # ==========================================================

    # Branches
    at('Branches', 'branch_name', '-1.8,10!')
    at('Branches', 'city',        '-1.5,9.2!')
    at('Branches', 'region',      '0,11.2!')

    # Customers
    at('Customers', 'national_id', '8.8,10!', unique=True)
    at('Customers', 'first_name',  '7,11.2!')
    at('Customers', 'last_name',   '8.5,11.4!')
    at('Customers', 'email',       '5.8,10.8!')
    at('Customers', 'risk_score',  '7.5,9!')

    # Accounts
    at('Accounts', 'account_number', '5.2,8.2!', unique=True)
    at('Accounts', 'account_type',   '3.5,8.4!')
    at('Accounts', 'balance',        '2,6.2!')
    at('Accounts', 'status_a',       '5.2,6.5!')

    # Transactions
    at('Transactions', 'amount',     '5.3,5!')
    at('Transactions', 'channel',    '5.3,4!')
    at('Transactions', 'ip_address', '2,3!')
    at('Transactions', 'status_t',   '5,3!')
    at('Transactions', 'location',   '1.5,4!')

    # FraudRules
    at('FraudRules', 'rule_name',        '-1.8,0.5!', unique=True)
    at('FraudRules', 'threshold_amount', '0,-.2!')
    at('FraudRules', 'is_active',        '-1.8,1.5!')

    # FraudAlerts
    at('FraudAlerts', 'alert_type', '3.5,-.2!')
    at('FraudAlerts', 'severity',   '2,0!')
    at('FraudAlerts', 'status_fa',  '5,2!')

    # FraudReports
    at('FraudReports', 'findings',       '7,-.2!')
    at('FraudReports', 'recommendation', '8.5,0.5!')
    at('FraudReports', 'status_fr',      '8.8,1.8!')

    # FlaggedAccounts
    at('FlaggedAccounts', 'reason',        '10,5.5!')
    at('FlaggedAccounts', 'risk_level',    '8,7.2!')
    at('FlaggedAccounts', 'review_status', '10.3,6!')

    # Users
    at('Users', 'username',  '13.3,4!', unique=True)
    at('Users', 'role',      '11.5,5.3!')
    at('Users', 'full_name', '13,5.5!')

    # AuditLog
    at('AuditLog', 'action',         '10.5,0!')
    at('AuditLog', 'table_affected', '13.3,0.3!')

    # LoginAttempts
    at('LoginAttempts', 'ip_address_l', '16.3,1.8!')
    at('LoginAttempts', 'success',      '14.5,3.8!')

    # ==========================================================
    #  RELATIONSHIPS
    # ==========================================================

    # 1) Branches --< Accounts
    rel('R1', 'Has', '1.2,8.5!')
    link('R1', 'Branches',  '1')
    link('R1', 'Accounts',  'N')

    # 2) Customers --< Accounts
    rel('R2', 'Owns', '5.8,8.5!')
    link('R2', 'Customers', '1')
    link('R2', 'Accounts',  'N')

    # 3) Accounts --< Transactions
    rel('R3', 'Generates', '3.5,5.5!')
    link('R3', 'Accounts',     '1')
    link('R3', 'Transactions', 'N')

    # 4) Transactions --< FraudAlerts
    rel('R4', 'Triggers', '3.5,2.5!')
    link('R4', 'Transactions', '1')
    link('R4', 'FraudAlerts',  'N')

    # 5) FraudRules --< FraudAlerts
    rel('R5', 'Applies', '1.5,1!')
    link('R5', 'FraudRules',  '1')
    link('R5', 'FraudAlerts', 'N')

    # 6) FraudAlerts --- FraudReports (1:1)
    rel('R6', 'Investigates', '5.3,1!')
    link('R6', 'FraudAlerts',  '1')
    link('R6', 'FraudReports', '1')

    # 7) Accounts --< FlaggedAccounts
    rel('R7', 'Flags', '6.5,6.5!')
    link('R7', 'Accounts',        '1')
    link('R7', 'FlaggedAccounts', 'N')

    # 8) Users --< FraudAlerts (resolved_by)
    rel('R8', 'Resolves', '8,3!')
    link('R8', 'Users',       '1')
    link('R8', 'FraudAlerts', 'N')

    # 9) Users --< FlaggedAccounts (reviewed_by)
    rel('R9', 'Reviews', '10.5,5!')
    link('R9', 'Users',            '1')
    link('R9', 'FlaggedAccounts', 'N')

    # 10) Users --< FraudReports (investigator_id)
    rel('R10', 'Authors', '9.5,2!')
    link('R10', 'Users',        '1')
    link('R10', 'FraudReports', 'N')

    # 11) Users --< AuditLog
    rel('R11', 'Performs', '11.5,2.5!')
    link('R11', 'Users',    '1')
    link('R11', 'AuditLog', 'N')

    # 12) Users --< LoginAttempts
    rel('R12', 'Attempts', '13.5,3.5!')
    link('R12', 'Users',         '1')
    link('R12', 'LoginAttempts', 'N')

    # ── Render (no legend — Pillow adds it after) ──
    output_path = os.path.join(OUTPUT_DIR, 'chen_erd')
    dot.render(output_path, cleanup=True)
    print(f"[OK] Base ERD rendered.")
    return output_path + '.png'


def draw_legend(erd_path):
    """Draw a proper legend with real shapes using Pillow, then paste it
    onto the top-right corner of the ERD image."""
    from PIL import Image, ImageDraw, ImageFont

    # ── Load the ERD ──
    erd = Image.open(erd_path)
    erd_w, erd_h = erd.size

    # ── Legend sizing ──
    LW, ROW_H = 420, 44
    rows = 7
    TITLE_H = 48
    PAD = 16
    LH = TITLE_H + rows * ROW_H + PAD * 2
    SHAPE_X = PAD + 40          # center of shape column
    TEXT_X  = PAD + 90          # left edge of text column

    leg = Image.new('RGBA', (LW, LH), (255, 255, 255, 245))
    d = ImageDraw.Draw(leg)

    # Border
    d.rectangle([0, 0, LW-1, LH-1], outline='#888888', width=2)

    # ── Try to load a nice font, fallback to default ──
    try:
        title_font = ImageFont.truetype("arial.ttf", 20)
        label_font = ImageFont.truetype("arial.ttf", 16)
    except:
        title_font = ImageFont.load_default()
        label_font = ImageFont.load_default()

    # ── Title ──
    d.text((LW // 2, PAD + 10), "Legend (Chen Notation)",
           fill='black', font=title_font, anchor='mm')

    # ── Color constants ──
    ENT_FILL   = '#3B7DD8'
    WEAK_FILL  = '#FFE0B2'
    WEAK_BDR   = '#EF6C00'
    REL_FILL   = '#E8F5E9'
    REL_BDR    = '#43A047'
    PK_FILL    = '#FFF3CD'
    PK_BDR     = '#D4A017'
    AT_FILL    = '#EDF2FB'
    AT_BDR     = '#9DB8D8'
    CARD_COLOR = '#C62828'

    def row_y(i):
        return TITLE_H + PAD + i * ROW_H + ROW_H // 2

    # ── Row 0: Strong Entity — filled rectangle ──
    y = row_y(0)
    d.rectangle([SHAPE_X-28, y-12, SHAPE_X+28, y+12],
                fill=ENT_FILL, outline=ENT_FILL, width=2)
    d.text((TEXT_X, y), "Strong Entity", fill='black', font=label_font, anchor='lm')

    # ── Row 1: Weak Entity — rectangle with orange border ──
    y = row_y(1)
    d.rectangle([SHAPE_X-28, y-12, SHAPE_X+28, y+12],
                fill=WEAK_FILL, outline=WEAK_BDR, width=3)
    d.text((TEXT_X, y), "Weak / Dependent Entity", fill='black', font=label_font, anchor='lm')

    # ── Row 2: Relationship — diamond ──
    y = row_y(2)
    diamond = [(SHAPE_X, y-16), (SHAPE_X+28, y), (SHAPE_X, y+16), (SHAPE_X-28, y)]
    d.polygon(diamond, fill=REL_FILL, outline=REL_BDR, width=2)
    d.text((TEXT_X, y), "Relationship", fill='black', font=label_font, anchor='lm')

    # ── Row 3: Primary Key — gold ellipse with underlined text ──
    y = row_y(3)
    d.ellipse([SHAPE_X-30, y-13, SHAPE_X+30, y+13],
              fill=PK_FILL, outline=PK_BDR, width=2)
    # underlined "attr" inside
    d.text((SHAPE_X, y-2), "attr", fill='black', font=label_font, anchor='mm')
    d.line([SHAPE_X-14, y+9, SHAPE_X+14, y+9], fill='black', width=1)
    d.text((TEXT_X, y), "Primary Key (underlined)", fill='black', font=label_font, anchor='lm')

    # ── Row 4: Unique Key — blue ellipse, gold border, underlined ──
    y = row_y(4)
    d.ellipse([SHAPE_X-30, y-13, SHAPE_X+30, y+13],
              fill=AT_FILL, outline=PK_BDR, width=2)
    d.text((SHAPE_X, y-2), "attr", fill='black', font=label_font, anchor='mm')
    d.line([SHAPE_X-14, y+9, SHAPE_X+14, y+9], fill='black', width=1)
    d.text((TEXT_X, y), "Unique Key (underlined)", fill='black', font=label_font, anchor='lm')

    # ── Row 5: Attribute — blue ellipse, blue border ──
    y = row_y(5)
    d.ellipse([SHAPE_X-30, y-13, SHAPE_X+30, y+13],
              fill=AT_FILL, outline=AT_BDR, width=2)
    d.text((SHAPE_X, y), "attr", fill='black', font=label_font, anchor='mm')
    d.text((TEXT_X, y), "Attribute", fill='black', font=label_font, anchor='lm')

    # ── Row 6: Cardinality ──
    y = row_y(6)
    d.text((SHAPE_X, y), "1, N", fill=CARD_COLOR, font=title_font, anchor='mm')
    d.text((TEXT_X, y), "Cardinality", fill='black', font=label_font, anchor='lm')

    # ── Paste legend onto ERD (top-right with margin) ──
    margin = 20
    paste_x = erd_w - LW - margin
    paste_y = margin
    erd.paste(leg, (paste_x, paste_y), leg)
    erd.save(erd_path)
    print(f"[OK] Legend composited. Final: {os.path.getsize(erd_path) / 1024:.0f} KB")


if __name__ == '__main__':
    path = create_chen_erd()
    draw_legend(path)
    print("Done!")
