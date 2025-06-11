#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import random
import uuid
from datetime import datetime, timedelta


def random_ipv6():
    return ":".join(format(random.randint(0, 0xffff), '04x') for _ in range(8))

def sql_str(val):
    return "'" + str(val) + "'"

def random_category_ids():
    cnt = random.randint(1, 3)
    arr = [random.randint(1, 100) for _ in range(cnt)]
    return "[" + ",".join(str(x) for x in arr) + "]"

num_rows = 50000
# Данные за предыдущие 3 месяца до сегодня
start_date = datetime.now() - timedelta(days=90)
num_days = 180
num_seconds = num_days * 24 * 3600
num_back_step_days = 90
num_back_step_seconds = num_back_step_days * 24 * 3600

one_step_seconds = num_seconds // num_rows

for step in range(num_rows):
    random_seconds = random.randint(0, 180 * 24 * 3600)
    timemark_dt = start_date + timedelta(seconds=random_seconds)
    timemark = timemark_dt.strftime('%Y-%m-%d %H:%M:%S')
    datehourmark = timemark_dt.replace(minute=0, second=0, microsecond=0).strftime('%Y-%m-%d %H:%M:%S')
    datemark = timemark_dt.strftime('%Y-%m-%d')
    time_step = -num_back_step_seconds + one_step_seconds * step
    
    sign = 1
    delay = random.randint(0, 1000000)
    duration = random.randint(0, 1000000)
    event_val = random.choice(["impression", "click", "view", "direct", "src.win", "src.bid", "src.skip", "src.nobid", "src.fail"])
    status = random.randint(0, 5)
    auc_id = f"UUIDStringToNum('{uuid.uuid4()}')"
    auc_type = random.choice([0, 1, 2, 3])
    imp_id = f"UUIDStringToNum('{uuid.uuid4()}')"
    impad_id = f"UUIDStringToNum('{uuid.uuid4()}')"
    extauc_id = "extauc_" + str(random.randint(1, 1000))
    extimp_id = "extimp_" + str(random.randint(1, 1000))
    source_id = random.randint(1, 10)
    network = "network_" + str(random.randint(1, 10))
    platform_type = random.choice([0, 1, 2, 3, 4])
    domain = "domain_" + str(random.randint(1, 10))
    app_id = random.randint(1, 10)
    zone_id = random.randint(1, 10)
    format_id = random.randint(1, 10)
    ad_w = random.randint(100, 1920)
    ad_h = random.randint(100, 1080)
    src_url = "http://src.url/" + str(random.randint(1, 1000))
    win_url = "http://win.url/" + str(random.randint(1, 1000))
    url_val = "http://target.url/" + str(random.randint(1, 1000))
    pricing_model = random.randint(0, 3)
    purchase_view_price = random.randint(1, 100) * 1000000000
    purchase_click_price = random.randint(1, 100) * 1000000000
    potential_view_price = random.randint(1, 100) * 1000000000
    potential_click_price = random.randint(1, 100) * 1000000000
    view_price = random.randint(1, 100) * 1000000000
    click_price = random.randint(1, 100) * 1000000000
    ud_id = "ud_" + str(random.randint(1, 1000))
    uu_id = f"UUIDStringToNum('{uuid.uuid4()}')"
    sess_id = f"UUIDStringToNum('{uuid.uuid4()}')"
    fingerprint = "fp_" + str(random.randint(1, 1000))
    etag = "etag_" + str(random.randint(1, 1000))
    carrier_id = random.randint(1, 10)
    country = random.choice(["RU", "US", "GB", "CN", "DE"])
    latitude = round(random.uniform(-90, 90), 6)
    longitude = round(random.uniform(-180, 180), 6)
    language = "en_US"
    ip_val = random_ipv6()
    ref_val = "http://ref.url/" + str(random.randint(1, 1000))
    page_url = "http://page.url/" + str(random.randint(1, 1000))
    ua = "Mozilla/5.0"
    device_id = random.randint(1, 10)
    device_type = random.randint(0, 5)
    os_id = random.randint(1, 10)
    browser_id = random.randint(1, 10)
    category_ids = random_category_ids()
    adblock = random.randint(0, 1)
    private_val = random.randint(0, 1)
    robot = random.randint(0, 1)
    proxy = random.randint(0, 1)
    backup = random.randint(0, 1)
    x_val = random.randint(0, 1920)
    y_val = random.randint(0, 1080)
    w_val = random.randint(100, 1920)
    h_val = random.randint(100, 1080)
    subid1 = "subid1_" + str(random.randint(1, 1000))
    subid2 = "subid2_" + str(random.randint(1, 1000))
    subid3 = "subid3_" + str(random.randint(1, 1000))
    subid4 = "subid4_" + str(random.randint(1, 1000))
    subid5 = "subid5_" + str(random.randint(1, 1000))
    created_at = timemark

    values = [
        sign,
        f"now() + {time_step}", #sql_str(timemark),
        f"toStartOfHour(now() + {time_step})", # sql_str(datehourmark),
        f"toDate(now() + {time_step})", # sql_str(datemark),
        delay,
        duration,
        sql_str(event_val),
        status,
        auc_id,
        auc_type,
        imp_id,
        impad_id,
        sql_str(extauc_id),
        sql_str(extimp_id),
        source_id,
        sql_str(network),
        platform_type,
        sql_str(domain),
        app_id,
        zone_id,
        format_id,
        ad_w,
        ad_h,
        sql_str(src_url),
        sql_str(win_url),
        sql_str(url_val),
        pricing_model,
        purchase_view_price,
        purchase_click_price,
        potential_view_price,
        potential_click_price,
        view_price,
        click_price,
        sql_str(ud_id),
        uu_id,
        sess_id,
        sql_str(fingerprint),
        sql_str(etag),
        carrier_id,
        sql_str(country),
        latitude,
        longitude,
        sql_str(language),
        sql_str(ip_val),
        sql_str(ref_val),
        sql_str(page_url),
        sql_str(ua),
        device_id,
        device_type,
        os_id,
        browser_id,
        category_ids,
        adblock,
        private_val,
        robot,
        proxy,
        backup,
        x_val,
        y_val,
        w_val,
        h_val,
        sql_str(subid1),
        sql_str(subid2),
        sql_str(subid3),
        sql_str(subid4),
        sql_str(subid5),
        sql_str(created_at)
    ]

    values_str = ", ".join(str(v) for v in values)
    print(f"INSERT INTO stats.events_local VALUES ({values_str});")