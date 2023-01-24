WITH forecast_no_temp AS
 (SELECT MAX(fn.forecast_no) forecast_no
    FROM apsuser.forecast_nos@fssnew fn, apsuser.forecast_config@fssnew fc
   WHERE fn.organization_id = 86146
     AND fn.forecast_type = fc.fst_type
     AND fn.organization_id = fc.organization_id
     AND fc.demand_type = 1002
     AND fn.forecast_no LIKE 'SSF%'),
group_temp AS -- 空
 (SELECT MAX(t.group_id) group_id
    FROM fss.fss_configuration_execution@fssnew t,
         fss.fss_job_execution_log@fssnew       fl
   WHERE t.cfg_value IN (SELECT t.attribute2
                           FROM apsuser.common_config_info@fssnew t
                          WHERE t.config_type = 'pageLimitScheduleSolution'
                            AND t.attribute1 = 'apsSupplyDmandMatch'
                            AND t.is_valid = 'Y'
                            AND t.organization_id = 86146)
     AND t.cfg_name = 'scheduleSolution'
     AND t.cfg_type = 'KEY_INPUT_CONFIG'
     AND t.creation_date > trunc(SYSDATE)
     AND fl.external_number_id = t.group_id
     AND EXISTS (SELECT 1
            FROM fss.fss_configuration_execution@fssnew hig
           WHERE hig.cfg_name = 'DEMAND_GR0SS_SP_P'
             AND hig.cfg_type = 'KEY_OUTPUT_CONFIG'
             AND hig.cfg_value = 'high'
             AND hig.group_id = t.group_id)),
item_temp AS
 (SELECT decode(t.item_type, 'P', t.hisi_attribute, 'AI', t.pur_attribute) purchase_attribute,
         (CASE
           WHEN t.cfg_value = 1 THEN
            t.safe_inv1
           ELSE
            t.safe_inv2
         END) safe_inv,
         t.*
    FROM (SELECT b.segment1 item,
                 b.inventory_item_id,
                 b.organization_id,
                 b.scheduling_organization_id,
                 b.item_type_erp,
                 b.inventory_item_status_code status,
                 b.gross_die,
                 b.primary_uom_code,
                 (SELECT (SELECT nvl((SELECT MAX(pasl.fixed_lot_multiple) keep(dense_rank FIRST ORDER BY decode(pasl.supplier_site_id, NULL, 2, 1), pasl.asl_id)
                                       FROM scdpuser.v_approved_supplier_list pasl,
                                            scdpuser.v_sourcing_rules         sr
                                      WHERE pasl.supplier_code =
                                            sr.supplier_code
                                        AND pasl.item_number = sr.item_number
                                        AND pasl.asl_status_id IN (4, 20)
                                        AND nvl(pasl.disable_flag, 'N') = 'N'
                                        AND sr.allocation_percent > 0
                                        AND trunc(SYSDATE) BETWEEN
                                            sr.effective_date AND
                                            nvl(sr.disable_date, SYSDATE + 1)
                                        AND sr.rank = 1
                                        AND sr.item_number = b.segment1),
                                     (SELECT MAX(pasl.fixed_lot_multiple) keep(dense_rank FIRST ORDER BY decode(nvl(pasl.supplier_site_id, -1), -1, 2, 1), pasl.asl_id)
                                        FROM scdpuser.v_approved_supplier_list pasl
                                       WHERE pasl.item_number = b.segment1
                                         AND pasl.asl_status_id IN (4, 20)
                                         AND nvl(pasl.disable_flag, 'N') = 'N'))
                            FROM dual) mpq
                    FROM dual) mpq,
                 (SELECT (SELECT nvl((SELECT MAX(pasl.min_order_quantity) keep(dense_rank FIRST ORDER BY decode(pasl.supplier_site_id, NULL, 2, 1), pasl.asl_id)
                                       FROM scdpuser.v_approved_supplier_list pasl,
                                            scdpuser.v_sourcing_rules         sr
                                      WHERE pasl.supplier_code =
                                            sr.supplier_code
                                        AND pasl.item_number = sr.item_number
                                        AND pasl.asl_status_id IN (4, 20)
                                        AND nvl(pasl.disable_flag, 'N') = 'N'
                                        AND sr.allocation_percent > 0
                                        AND trunc(SYSDATE) BETWEEN
                                            sr.effective_date AND
                                            nvl(sr.disable_date, SYSDATE + 1)
                                        AND sr.rank = 1
                                        AND sr.item_number = b.segment1),
                                     (SELECT MAX(pasl.min_order_quantity) keep(dense_rank FIRST ORDER BY decode(nvl(pasl.supplier_site_id, -1), -1, 2, 1), pasl.asl_id)
                                        FROM scdpuser.v_approved_supplier_list pasl
                                       WHERE pasl.item_number = b.segment1
                                         AND pasl.asl_status_id IN (4, 20)
                                         AND nvl(pasl.disable_flag, 'N') = 'N'))
                            FROM dual) moq
                    FROM dual) moq,
                 b.attribute5 part_no,
                 (SELECT SUM(wip.reach_qty)
                    FROM fss.fss_wip_way_detail@fssnew wip
                   WHERE wip.organization_id IN
                         (SELECT to_number(ci.name)
                            FROM apsuser.config_info@fssnew ci
                           WHERE ci.type = 'APS_ORG_ID'
                             AND ci.organization_id =
                                 b.scheduling_organization_id)
                     AND wip.item_id = b.inventory_item_id
                     AND wip.source_code = 'MOVE_REPORT') wip,
                 (SELECT SUM(v.reach_qty)
                    FROM apsuser.v_move_report_all@fssnew v
                   WHERE v.organization_id IN
                         (SELECT to_number(ci.name)
                            FROM apsuser.config_info@fssnew ci
                           WHERE ci.type = 'APS_ORG_ID'
                             AND ci.organization_id =
                                 b.scheduling_organization_id)
                     AND v.item_id = b.inventory_item_id) wip_all,
                 (SELECT ci.name
                    FROM apsuser.config_info@fssnew ci
                   WHERE ci.type = 'ItemProperty'
                     AND ci.code = b.property
                     AND ci.organization_id = b.organization_id) property,
                 (SELECT v.total_qty
                    FROM apsuser.v_forecast_week@fssnew v
                   WHERE v.forecast_no IN
                         (SELECT n.forecast_no FROM apsuser.forecast_no_temp n)
                     AND v.item_id = b.inventory_item_id
                     AND v.organization_id = b.organization_id) tactic,
                 (SELECT t.cfg_value
                    FROM fss.fss_configuration_execution@fssnew t
                   WHERE t.group_id IN (SELECT g.group_id FROM group_temp g)
                     AND t.cfg_name = 'scheduleSystem'
                     AND t.cfg_type = 'KEY_INPUT_CONFIG') cfg_value,
                 (SELECT g.item_type_erp
                    FROM fss.fss_items_info_gather@fssnew g
                   WHERE g.item_id = b.inventory_item_id) item_type,
                 (SELECT decode(fg.item_type_erp,
                                'AI',
                                mb.fixed_lead_time,
                                'P',
                                mb.full_lead_time) lead_time
                    FROM apsuser.mv_mtl_system_items_b@fssnew mb,
                         fss.fss_items_info_gather@fssnew     fg
                   WHERE fg.item_id = mb.inventory_item_id
                     AND mb.inventory_item_id = b.inventory_item_id
                     AND mb.organization_id = b.organization_id) lead_time,
                 (SELECT c.name
                    FROM apsuser.config_info@fssnew c
                   WHERE c.type = 'HISIAttribute'
                     AND c.organization_id = b.organization_id
                     AND c.code = b.hisiattribute) hisi_attribute,
                 (SELECT c.name
                    FROM apsuser.config_info@fssnew c
                   WHERE c.type = 'PurchaseAttribute'
                     AND c.organization_id = b.organization_id
                     AND c.code = b.purchase_attribute) pur_attribute,
                 (SELECT nvl(SUM(ms.quantity), 0)
                    FROM scdpuser.subinventory_place sp,
                         scdpuser.material_storage   ms
                   WHERE sp.strategy_flag = 'Y'
                     AND sp.subinventory_code = ms.subinventory_code
                     AND sp.organization_id = ms.organization_id
                     AND ms.organization_id IN
                         (SELECT to_number(ci.name)
                            FROM apsuser.config_info@fssnew ci
                           WHERE ci.type = 'APS_ORG_ID'
                             AND ci.organization_id = 86146)
                     AND ms.inventory_item_id = b.inventory_item_id
                   GROUP BY ms.inventory_item_id) stock_qty,
                 (SELECT up.planner_login_name
                    FROM apsuser.user_planner@fssnew up
                   WHERE up.planner_code = b.planner_code
                     AND up.organization_id = b.organization_id) master_planner_name,
                 (SELECT up.product
                    FROM apsuser.user_planner@fssnew up
                   WHERE up.planner_code = b.planner_code
                     AND up.organization_id = b.organization_id) product,
                 (SELECT p.full_name
                    FROM apsuser.mv_per_all_people_f@fssnew p
                   WHERE p.person_id = b.buyer_id) buyer_name,
                 (SELECT ci.name
                    FROM apsuser.config_info@fssnew ci
                   WHERE ci.type = 'ItemPlannerType'
                     AND ci.code = b.planner_code
                     AND ci.organization_id = b.organization_id) planner_code,
                 nvl((SELECT SUM(fd.demand_quantity)
                       FROM fss.mrp_demand@fssnew fd
                      WHERE fd.group_id IN
                            (SELECT g.group_id FROM group_temp g)
                        AND fd.item_id = b.inventory_item_id
                        AND EXISTS
                      (SELECT 1
                               FROM apsuser.forecast_config@fssnew fc
                              WHERE fc.fst_level = 1002
                                AND fc.is_valid = 'Y'
                                AND fc.organization_id =
                                    fd.forecast_organization_id
                                AND fc.fst_type = fd.forecast_type)),
                     0) safe_inv1,
                 nvl((SELECT SUM(fd.demand_quantity)
                       FROM fss.mrp_demand@fssnew fd
                      WHERE fd.group_id IN
                            (SELECT g.group_id FROM group_temp g)
                        AND fd.item_id = b.inventory_item_id
                        AND EXISTS
                      (SELECT 1
                               FROM apsuser.forecast_config@fssnew fc
                              WHERE fc.fst_level = 1002
                                AND fc.is_valid = 'Y'
                                AND fc.organization_id =
                                    fd.forecast_organization_id
                                AND fc.fst_type = fd.forecast_type)),
                     0) safe_inv2,
                 (SELECT SUM(ms.quantity) qty
                    FROM scdpuser.carton_info ci, scdpuser.material_storage ms
                   WHERE ci.valid_date IS NOT NULL
                     AND ci.carton_no = ms.carton_no
                     AND ci.organization_id = ms.organization_id
                     AND (trunc(ci.valid_date) - trunc(SYSDATE)) > 0
                     AND (trunc(ci.valid_date) - trunc(SYSDATE)) <= 30
                     AND ms.inventory_item_id = b.inventory_item_id
                     AND ms.organization_id IN
                         (SELECT to_number(ci.name)
                            FROM apsuser.config_info@fssnew ci
                           WHERE ci.type = 'APS_ORG_ID'
                             AND ci.organization_id = 86146)) pre_over,
                 (SELECT ci.name
                    FROM fss.fss_items_info_gather@fssnew fg,
                         apsuser.config_info@fssnew       ci
                   WHERE ci.type = 'SupplyType'
                     AND fg.wip_supply_type_erp = ci.code
                     AND ci.organization_id = fg.fulfil_org_id
                     AND fg.item_id = b.inventory_item_id) supply_type,
                 row_number() over(PARTITION BY b.inventory_item_id, b.scheduling_organization_id ORDER BY decode(b.organization_id, b.fulfil_org_id, 1, 2), decode(b.item_type_erp, 'AI', 1, 2)) rn
            FROM apsuser.mtl_system_items_b@fssnew b
           WHERE b.item_type_erp NOT IN
                 ('SV', 'SW', 'OP', 'FRT', 'GP', 'REF', 'MTS')
             AND b.segment1 NOT LIKE 'A%'
             AND b.segment1 NOT LIKE '88%'
             AND b.scheduling_organization_id = 86146
             AND b.organization_id IN
                 (SELECT to_number(ci.name)
                    FROM apsuser.config_info@fssnew ci
                   WHERE ci.type = 'APS_ORG_ID'
                     AND ci.organization_id = 86146)) t
   WHERE rn = 1),
storage_temp AS
-- 最耗时，52 分钟
 (SELECT b.scheduling_organization_id,
         b.organization_id,
         b.inventory_item_id,
         SUM(b.good_qty_not_vmi) good_qty_not_vmi,
         SUM(b.good_qty_with_vmi) good_qty_with_vmi,
         SUM(b.good_qty_with_vmi_over_date) good_qty_with_vmi_over_date,
         SUM(b.good_qty_with_vmi_locked) good_qty_with_vmi_locked,
         SUM(b.bad_qty) bad_qty,
         SUM(b.sx) sx
    FROM (SELECT b.scheduling_organization_id,
                 b.organization_id,
                 b.inventory_item_id,
                 CASE
                   WHEN substrb(ms.subinventory_code, 3, 2) IN
                        ('AP', 'AR', 'BP', 'CP', 'JP', 'SP', 'ZT', 'VC') THEN
                    ms.qty
                   ELSE
                    0
                 END good_qty_not_vmi,
                 CASE
                   WHEN substrb(ms.subinventory_code, 3, 2) IN
                        ('AP', 'AR', 'BP', 'CP', 'JP', 'SP', 'ZT', 'VC', 'VM') THEN
                    ms.qty
                   ELSE
                    0
                 END good_qty_with_vmi,
                 CASE
                   WHEN substrb(ms.subinventory_code, 3, 2) IN
                        ('AP', 'AR', 'BP', 'CP', 'JP', 'SP', 'ZT', 'VC', 'VM') AND
                        trunc((SELECT ci.valid_date
                                FROM scdpuser.carton_info ci
                               WHERE ci.carton_no = ms.carton_no
                                 AND ci.organization_id = ms.organization_id)) <=
                        trunc(SYSDATE) THEN
                    ms.qty
                   ELSE
                    0
                 END good_qty_with_vmi_over_date,
                 CASE
                   WHEN substrb(ms.subinventory_code, 3, 2) IN
                        ('AP', 'AR', 'BP', 'CP', 'JP', 'SP', 'ZT', 'VC', 'VM') AND
                        ms.lock_flag = 'Y' THEN
                    ms.qty
                   ELSE
                    0
                 END good_qty_with_vmi_locked,
                 CASE
                   WHEN substrb(ms.subinventory_code, 3, 2) IN
                        ('DP', 'GZ', 'WX') THEN
                    ms.qty
                   ELSE
                    0
                 END bad_qty,
                 CASE
                   WHEN substrb(ms.subinventory_code, 3, 2) IN ('SX') THEN
                    ms.qty
                   ELSE
                    0
                 END sx
            FROM item_temp b, apsuser.mv_item_ver_init_inv@fssnew ms
           WHERE 1 = 1
             AND b.inventory_item_id = ms.inventory_item_id
             AND ms.organization_id IN
                 (SELECT to_number(ci.name)
                    FROM apsuser.config_info@fssnew ci
                   WHERE ci.type = 'APS_ORG_ID'
                     AND ci.organization_id = b.scheduling_organization_id)
             AND NOT EXISTS
           (SELECT 1
                    FROM apsuser.subinventory_place@fssnew sp
                   WHERE ms.subinventory_code = sp.detail_subinventory
                     AND ms.organization_id = sp.organization_id
                     AND sp.is_summary = 'Y')
          UNION ALL
          --IO status为N 且箱号状态非ASN CANCEL/CANCELLATION/REJECTED 且接收子库APS flag为Y 且交易类型是PO Receive\ VMI PO Receive 且（供应商HK7、SH2、NNFG和HFJ的标准PO待入库部分或 接收子库等于VMI）
          SELECT b.scheduling_organization_id,
                 b.organization_id,
                 b.inventory_item_id,
                 mt.transaction_quantity * -1 good_qty_not_vmi,
                 mt.transaction_quantity * -1 good_qty_with_vmi,
                 (CASE
                   WHEN trunc(car.valid_date) <= trunc(SYSDATE) THEN
                    mt.transaction_quantity * -1
                   ELSE
                    0
                 END) good_qty_with_vmi_over_date,
                 (CASE
                   WHEN mt.lock_flag = 'Y' THEN
                    mt.transaction_quantity * -1
                   ELSE
                    0
                 END) good_qty_with_vmi_locked,
                 0 bad_qty,
                 0 sx
            FROM item_temp             b,
                 apsuser.mv_asn@fssnew mt,
                 scdpuser.carton_info  car,
                 scdpuser.io_type      io
           WHERE mt.inventory_item_id = b.inventory_item_id
             AND car.carton_no = mt.carton_no
             AND car.need_qc = 'Y'
             AND mt.organization_id IN
                 (SELECT to_number(ci.name)
                    FROM apsuser.config_info@fssnew ci
                   WHERE ci.type = 'APS_ORG_ID'
                     AND ci.organization_id = b.scheduling_organization_id)
             AND (mt.subinventory_code LIKE '%VMI%' OR
                 mt.vendor_id NOT IN (62700, 22395639))
             AND mt.carton_status NOT IN (1006, 1008, 1009)
             AND mt.io_type_id = io.io_type_id
             AND mt.organization_id = io.organization_id
             AND io.type_code IN ('VMI_PO_RECEIVE', 'PO_IN')
             AND EXISTS
           (SELECT 1
                    FROM apsuser.subinventory_place@fssnew sp
                   WHERE sp.subinventory_code = mt.subinventory_code
                     AND sp.organization_id = mt.organization_id
                     AND sp.aps_flag = 'Y')
          UNION ALL
          --联合排产的ASN
          SELECT b.scheduling_organization_id,
                 b.organization_id,
                 b.inventory_item_id,
                 wip.reach_qty                good_qty_not_vmi,
                 wip.reach_qty                good_qty_with_vmi,
                 wip.reach_qty                good_qty_with_vmi_over_date,
                 wip.reach_qty_locked         good_qty_with_vmi_locked,
                 0                            bad_qty,
                 0                            sx
            FROM fss.fss_wip_way_detail@fssnew wip, item_temp
           WHERE wip.item_id = b.inventory_item_id
             AND wip.source_code = 'ASN'
             AND wip.organization_id IN
                 (SELECT to_number(ci.name)
                    FROM apsuser.config_info@fssnew ci
                   WHERE ci.type = 'APS_ORG_ID'
                     AND ci.organization_id = b.scheduling_organization_id)
          --不良品和送修
          UNION ALL
          SELECT b.scheduling_organization_id,
                 b.organization_id,
                 b.inventory_item_id,
                 0 good_qty_not_vmi,
                 0 good_qty_with_vmi,
                 0 good_qty_with_vmi_over_date,
                 0 good_qty_with_vmi_locked,
                 CASE
                   WHEN substrb(mt.subinventory_code, 3, 2) IN
                        ('DP', 'GZ', 'WX') THEN
                    mt.transaction_quantity
                   ELSE
                    0
                 END bad_qty,
                 CASE
                   WHEN substrb(mt.subinventory_code, 3, 2) IN ('SX') THEN
                    mt.transaction_quantity
                   ELSE
                    0
                 END sx
            FROM item_temp b, apsuser.mv_asn@fssnew mt
           WHERE mt.inventory_item_id = b.inventory_item_id
             AND mt.organization_id IN
                 (SELECT to_number(ci.name)
                    FROM apsuser.config_info@fssnew ci
                   WHERE ci.type = 'APS_ORG_ID'
                     AND ci.organization_id = b.scheduling_organization_id)
             AND substrb(mt.subinventory_code, 3, 2) IN
                 ('DP', 'GZ', 'WX', 'SX')
             AND mt.carton_status NOT IN (1006, 1008, 1009)) b
   GROUP BY b.scheduling_organization_id,
            b.organization_id,
            b.inventory_item_id),
gross_temp AS
 (SELECT b.scheduling_organization_id,
         b.organization_id,
         b.inventory_item_id,
         SUM(CASE
               WHEN trunc(mgr.demand_date, 'MONTH') < trunc(SYSDATE, 'MONTH') THEN
                mgr.demand_quantity
               ELSE
                0
             END) m0,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(SYSDATE, 'MONTH'),
                    mgr.demand_quantity,
                    0)) m1,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 1), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m2,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 2), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m3,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 3), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m4,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 4), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m5,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 5), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m6,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 6), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m7,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 7), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m8,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 8), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m9,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 9), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m10,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 10), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m11,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 11), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m12,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 12), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m13,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 13), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m14,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 14), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m15,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 15), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m16,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 16), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m17,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 17), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m18,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 18), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m19,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 19), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m20,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 20), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m21,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 21), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m22,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 22), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m23,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 23), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m24,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 24), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m25,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 25), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m26,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 26), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m27,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 27), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m28,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 28), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m29,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 29), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m30,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 30), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m31,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 31), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m32,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 32), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m33,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 33), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m34,
         SUM(decode(trunc(mgr.demand_date, 'MONTH'),
                    trunc(add_months(SYSDATE, 34), 'MONTH'),
                    mgr.demand_quantity,
                    0)) m35,
         SUM(CASE
               WHEN trunc(mgr.demand_date, 'MONTH') >=
                    trunc(add_months(SYSDATE, 35), 'MONTH') THEN
                mgr.demand_quantity
               ELSE
                0
             END) m36,
         SUM(CASE
               WHEN trunc(mgr.demand_date, 'MONTH') BETWEEN
                    trunc(SYSDATE, 'MONTH') AND
                    trunc(add_months(SYSDATE, 5), 'MONTH') THEN
                mgr.demand_quantity
               WHEN trunc(mgr.demand_date, 'MONTH') < trunc(SYSDATE, 'MONTH') THEN
                mgr.demand_quantity
               ELSE
                0
             END) tot_gross,
         SUM(mgr.demand_quantity) erp_gross
    FROM item_temp b, apsuser.aps_gross_requirement@fssnew mgr
   WHERE 1 = 1
     AND b.inventory_item_id = mgr.item_id
     AND b.scheduling_organization_id = mgr.organization_id
     AND mgr.schedule_solution_id IN
         (SELECT t.cfg_id
            FROM apsuser.fss_config_header@fssnew t
           WHERE t.type_code = 'scheduleSolution'
             AND t.attribute2 = 'Y'
             AND t.is_valid = 'Y'
             AND t.organization_id = mgr.organization_id)
     AND mgr.demand_type = 'high'
   GROUP BY b.scheduling_organization_id,
            b.organization_id,
            b.inventory_item_id),
/*fss_temp AS
 (SELECT b.scheduling_organization_id,
         b.organization_id,
         b.inventory_item_id,
         SUM(fss_m1) fss_m1,
         SUM(fss_m2) fss_m2,
         SUM(fss_gross) fss_gross
    FROM (SELECT b.*,
                 nvl(fss.m1, 0) fss_m1,
                 nvl(fss.m2, 0) fss_m2,
                 (nvl(fss.m1, 0) + nvl(fss.m2, 0) + nvl(fss.m3, 0) + nvl(fss.m4, 0) + nvl(fss.m5, 0) +
                 nvl(fss.m6, 0) + nvl(fss.m7, 0) + nvl(fss.m8, 0) + nvl(fss.m9, 0) + nvl(fss.m10, 0) +
                 nvl(fss.m11, 0) + nvl(fss.m12, 0)) fss_gross
            FROM item_temp                     b,
                 apsuser.supply_demand_analyse fss
           WHERE 1 = 1
             AND fss.operator_id = 0
             AND fss.type_name = 'ForecastH'
             AND b.inventory_item_id = fss.item_id
             AND b.scheduling_organization_id = fss.organization_id) b
   WHERE b.fss_gross > 0
   GROUP BY b.scheduling_organization_id,
            b.organization_id,
            b.inventory_item_id),*/
fss_temp AS
 (SELECT NULL scheduling_organization_id,
         NULL organization_id,
         NULL inventory_item_id,
         NULL fss_m1,
         NULL fss_m2,
         NULL fss_gross
    FROM dual),
po_temp AS
 (SELECT b.scheduling_organization_id,
         b.organization_id,
         b.inventory_item_id,
         SUM(CASE
               WHEN trunc(nvl(wip.reach_date, SYSDATE), 'MONTH') <=
                    trunc(SYSDATE, 'MONTH') THEN
                wip.reach_qty
               ELSE
                0
             END) po1,
         SUM(decode(trunc(nvl(wip.reach_date, SYSDATE), 'MONTH'),
                    trunc(add_months(SYSDATE, 1), 'MONTH'),
                    wip.reach_qty,
                    0)) po2,
         SUM(decode(trunc(nvl(wip.reach_date, SYSDATE), 'MONTH'),
                    trunc(add_months(SYSDATE, 2), 'MONTH'),
                    wip.reach_qty,
                    0)) po3,
         SUM(decode(trunc(nvl(wip.reach_date, SYSDATE), 'MONTH'),
                    trunc(add_months(SYSDATE, 3), 'MONTH'),
                    wip.reach_qty,
                    0)) po4,
         SUM(decode(trunc(nvl(wip.reach_date, SYSDATE), 'MONTH'),
                    trunc(add_months(SYSDATE, 4), 'MONTH'),
                    wip.reach_qty,
                    0)) po5,
         SUM(decode(trunc(nvl(wip.reach_date, SYSDATE), 'MONTH'),
                    trunc(add_months(SYSDATE, 5), 'MONTH'),
                    wip.reach_qty,
                    0)) po6,
         SUM(decode(trunc(nvl(wip.reach_date, SYSDATE), 'MONTH'),
                    trunc(add_months(SYSDATE, 6), 'MONTH'),
                    wip.reach_qty,
                    0)) po7,
         SUM(decode(trunc(nvl(wip.reach_date, SYSDATE), 'MONTH'),
                    trunc(add_months(SYSDATE, 7), 'MONTH'),
                    wip.reach_qty,
                    0)) po8,
         SUM(decode(trunc(nvl(wip.reach_date, SYSDATE), 'MONTH'),
                    trunc(add_months(SYSDATE, 8), 'MONTH'),
                    wip.reach_qty,
                    0)) po9,
         SUM(decode(trunc(nvl(wip.reach_date, SYSDATE), 'MONTH'),
                    trunc(add_months(SYSDATE, 9), 'MONTH'),
                    wip.reach_qty,
                    0)) po10,
         SUM(decode(trunc(nvl(wip.reach_date, SYSDATE), 'MONTH'),
                    trunc(add_months(SYSDATE, 10), 'MONTH'),
                    wip.reach_qty,
                    0)) po11,
         SUM(CASE
               WHEN trunc(nvl(wip.reach_date, SYSDATE), 'MONTH') >=
                    trunc(add_months(SYSDATE, 11), 'MONTH') THEN
                wip.reach_qty
               ELSE
                0
             END) po12,
         SUM(wip.reach_qty) tot_po
    FROM (SELECT pm.item_id,
                 nvl(trunc(pm.delivery_date),
                     (SELECT trunc(nvl(least(pll.promised_date,
                                             SYSDATE + 365 * 10),
                                       pll.need_by_date) +
                                   nvl((SELECT pv.freight_period
                                         FROM apsuser.po_vendors@fssnew pv
                                        WHERE pv.vendor_id = pm.vendor_id
                                          AND pv.organization_id =
                                              pm.organization_id
                                          AND rownum = 1),
                                       0))
                        FROM apsuser.mv_po_line_locations_all@fssnew pll
                       WHERE pll.line_location_id = pm.line_location_id)) reach_date,
                 pm.quantity * nvl(d.gross_die, 1) *
                 nvl(d.key_routing_yield, 1) reach_qty
            FROM apsuser.po_match@fssnew          pm,
                 fss.fss_items_info_detail@fssnew d
           WHERE pm.po_match_status <> 1007
             AND pm.orgin_type IS NULL
             AND pm.organization_id = d.organization_id
             AND pm.item_id = d.inventory_item_id
             AND pm.vendor_id NOT IN (62700, 22395639)
             AND pm.quantity > 0
             AND EXISTS
           (SELECT 1
                    FROM apsuser.config_info@fssnew ci
                   WHERE ci.type = 'APS_ORG_ID'
                     AND to_number(ci.name) = d.organization_id
                     AND ci.organization_id = d.scheduling_organization_id)) wip,
         item_temp b
   WHERE wip.item_id = b.inventory_item_id
   GROUP BY b.scheduling_organization_id,
            b.organization_id,
            b.inventory_item_id),
pr_temp AS
 (SELECT b.scheduling_organization_id,
         b.organization_id,
         b.inventory_item_id,
         SUM(pr.quantity) pr_qty
    FROM apsuser.v_fss_pre_po_and_pr_from_erp@fssnew pr, item_temp b
   WHERE 1 = 1 --pr.type_code IN ('PO', 'PR')
     AND pr.scheduling_organization_id = b.scheduling_organization_id
     AND pr.item_id = b.inventory_item_id
   GROUP BY b.scheduling_organization_id,
            b.organization_id,
            b.inventory_item_id)
SELECT g3.alarm 预警标识,
       g3.item 编码,
   /*  g3.scheduling_organization_id 排产组织,
       g3.organization_id 履行组织,
       g3.purchase_attribute 属性,
       g3.part_no 型号,
       g3.status 状态,
       g3.item_type_erp 项目模板,
       g3.property 产品属性, */
       g3.moq  最小订单量,
       g3.mpq  最小包装量,
       -- g3.gross_die,
       g3.lead_time 货期,
       g3.master_planner_name 主计划,
       g3.planner_code 计划员代码,
       g3.product 产品小类,
       g3.tactic 连续性储备目标,
       g3.good_qty_not_vmi 良品库存_本地,
       g3.good_qty_with_vmi 良品库存_含vmi,
       g3.stock_qty 连续性库存,
       g3.bad_qty 故障品库存,
       g3.sx 送修库存,
       g3.wip 在制,
       g3.safe_inv 安全库存目标,
       g3.m0,
       g3.m1,
       g3.m2,
       g3.m3,
       g3.m4,
       g3.m5,
       g3.m6,
       g3.m7,
       g3.m8,
       g3.m9,
       g3.m10,
       g3.m11,
       g3.m12,
       g3.tot_gross 半年需求,
       g3.erp_gross 需求总量,
       g3.po1,
       g3.po2,
       g3.po3,
       g3.po4,
       g3.po5,
       g3.po6,
       g3.po7,
       g3.po8,
       g3.po9,
       g3.po10,
       g3.po11,
       g3.po12,
       g3.tot_po po总量,
       g3.pr_qty pr总量,
       g3.redundance 库存可用月,
       g3.redundance_of_supply 半年供应冗余,
       CASE
         WHEN nvl(g3.aver_gross, 0) = 0 THEN
          '月均需求为零'
         ELSE
          to_char(round(g3.good_qty_with_vmi / g3.aver_gross, 2),
                  'fm99999990.00')
       END 良品库存含vmi可用月,
       g3.safe_month 安全库存目标可用月,    -- 安全库存可用月
       g3.aver_gross 月均需求,
       g3.safeinv_month 储备月,
       g3.inv_level 库存水位目标,
       g3.safeinv_set 储备标识,      -- 储备设置
       g3.safeinv_flag 储备取消,     -- 储备flag， 字段值由原文字段描述取消储备变更为Y/N
       g3.tactic_flag 预警信息,      -- 策略加载异常, 将预警标识中的异常，拼接到原策略加载异常，合计异常信息：
       -- 毛需求=策略储备、安全库存>毛需求、毛需求=安全库存、(良品库存含VMI+所有PO)=扣减安全库存后的毛需求总和
       -- 本地库存不含VMI扣减安全库存后仍超1.5个月需求、(良品库存含VMI+所有PO)>扣减安全库存后的毛需求总和、安全库存超1.5个月需求
       g3.invwarning,
     -- g3.fss_m1,
     -- g3.fss_m2,
     -- g3.fss_gross,
     -- g3.sumgap,
     -- g3.gap2,
       g3.buyer_name 采购员,
       g3.primary_uom_code 单位uom,
       g3.supply_type,
       g3.wip_all 总在制_含所有非标,
       (g3.good_qty_with_vmi + g3.tot_po + g3.pr_qty + g3.erp_gross -
       g3.safe_inv - g3.tactic) 供应冗余_含pr,
       g3.good_qty_with_vmi_locked 锁定库存,
       nvl(g3.pre_over, 0) 三十天内即将超期,
       g3.m13,
       g3.m14,
       g3.m15,
       g3.m16,
       g3.m17,
       g3.m18,
       g3.m19,
       g3.m20,
       g3.m21,
       g3.m22,
       g3.m23,
       g3.m24,
       g3.m25,
       g3.m26,
       g3.m27,
       g3.m28,
       g3.m29,
       g3.m30,
       g3.m31,
       g3.m32,
       g3.m33,
       g3.m34,
       g3.m35,
       g3.m36,
       g3.good_qty_with_vmi_over_date 良品库存_超期含vmi,
       g3.pr_gap,
       g3.rchw_inv
  FROM (SELECT CASE
                 WHEN g2.redundance IS NULL OR
                      g2.redundance_of_supply IS NULL OR
                      g2.safe_month IS NULL OR g2.redundance >= 1.5 OR
                      g2.redundance_of_supply > 0 OR g2.safe_month > 1.5 THEN
                  'Y'
                 ELSE
                  'N'
               END alarm,
               g2.*,
               CASE
                 WHEN (g2.safeinv_set = '负需求不用做储备' OR
                      g2.safeinv_set = '无需求不用做储备') AND
                      nvl(g2.safe_inv, 0) <> 0 THEN
                  '建议取消储备'
                 ELSE
                  ''
               END safeinv_flag,
               CASE
                 WHEN (g2.safe_inv - tot_gross) > 0 THEN
                  '策略加载异常'
               END tactic_flag,
               CASE
                 WHEN (g2.good_qty_not_vmi - g2.m0 - g2.m1 + g2.safe_inv -
                      g2.inv_level) > 0 THEN
                  '库存偏大'
                 WHEN (g2.good_qty_not_vmi - g2.m0 - g2.m1 + g2.safe_inv -
                      g2.inv_level) < 0 THEN
                  '储备不足'
                 ELSE
                  ''
               END invwarning,
               round(t1.fss_m1) fss_m1,
               round(t1.fss_m2) fss_m2,
               round(t1.fss_gross) fss_gross,
               round(nvl((g2.erp_gross - t1.fss_gross), 0)) sumgap,
               round(nvl(((t1.fss_m1 + t1.fss_m2) - (g2.m0 + g2.m1 + g2.m2)),
                         0)) gap2,
               nvl((SELECT SUM(pr.new_order_quantity)
                     FROM apsuser.aps_plan_fst_pr@fssnew pr
                    WHERE pr.organization_id = 86146
                      AND pr.group_id =
                          (SELECT MAX(pr.group_id)
                             FROM apsuser.aps_plan_fst_pr@fssnew pr
                            WHERE pr.organization_id = 86146
                              AND pr.compile_designator IN
                                  ('EXH_NEW_VMI', 'EXH_NEW'))
                      AND pr.segment1 = g2.item
                      AND pr.status IN (10, 15, 17, 30, 50)
                      AND pr.compile_designator <> 'MANUAL_PURCHASE'
                      AND pr.suggested_order_date <=
                          trunc(pr.create_date) + 7),
                   0) pr_gap,
               nvl((SELECT SUM(mm.qty)
                     FROM apsuser.mv_mtl_onhand_h80@fssnew mm
                    WHERE mm.organization_id = 157
                      AND mm.item = g2.item),
                   0) rchw_inv
          FROM (SELECT g.*,
                       CASE
                         WHEN (substr(g.item, 0, 2) = '07') OR
                              (substr(g.item, 0, 2) = '08') THEN
                          ''
                         WHEN (((substr(g.item, 0, 2) != '07') OR
                              (substr(g.item, 0, 2) != '08')) AND
                              g.safeinv_month > 2) THEN
                          '储备偏高'
                         WHEN (((substr(g.item, 0, 2) != '07') OR
                              (substr(g.item, 0, 2) != '08')) AND
                              g.safeinv_month < 0) THEN
                          '负需求不用做储备'
                         WHEN (((substr(g.item, 0, 2) != '07') OR
                              (substr(g.item, 0, 2) != '08')) AND
                              g.aver_gross = 0) THEN
                          '无需求不用做储备'
                         WHEN (((substr(g.item, 0, 2) != '07') OR
                              (substr(g.item, 0, 2) != '08')) AND
                              g.safeinv_month > 0 AND g.safeinv_month < 1) THEN
                          '储备偏低'
                       END safeinv_set
                  FROM (SELECT t4.*,
                               nvl(t3.po1, 0) po1,
                               nvl(t3.po2, 0) po2,
                               nvl(t3.po3, 0) po3,
                               nvl(t3.po4, 0) po4,
                               nvl(t3.po5, 0) po5,
                               nvl(t3.po6, 0) po6,
                               nvl(t3.po7, 0) po7,
                               nvl(t3.po8, 0) po8,
                               nvl(t3.po9, 0) po9,
                               nvl(t3.po10, 0) po10,
                               nvl(t3.po11, 0) po11,
                               nvl(t3.po12, 0) po12,
                               nvl(t3.tot_po, 0) tot_po,
                               nvl((SELECT pt.pr_qty
                                     FROM pr_temp pt
                                    WHERE pt.inventory_item_id =
                                          t4.inventory_item_id
                                      AND pt.scheduling_organization_id =
                                          t4.scheduling_organization_id),
                                   0) pr_qty,
                               round(decode((nvl(t4.tot_gross, 0) -
                                            nvl(t4.tactic, 0)),
                                            0, --毛需求 - 安全库存 = 0
                                            NULL,
                                            (nvl(t4.good_qty_not_vmi, 0) -
                                            nvl(t4.safe_inv, 0)) /
                                            ((nvl(t4.tot_gross, 0) -
                                            nvl(t4.tactic, 0)) / 6)),
                                     2) redundance,
                               round((nvl(t4.good_qty_with_vmi, 0) +
                                     nvl(t3.tot_po, 0)) - (nvl(t4.tot_gross, 0) -
                                     nvl(t4.safe_inv, 0)),
                                     2) redundance_of_supply,
                               -- TODO   原逻辑：保留两位小数   
                               round(decode((nvl(t4.tot_gross, 0) -
                                            nvl(t4.safe_inv, 0)),
                                            0, -- 毛需求 - 安全库存 = 0
                                            NULL,
                                            nvl(t4.safe_inv, 0) /
                                            ((nvl(t4.tot_gross, 0) -
                                             nvl(t4.safe_inv, 0)) / 6)), -- 安全预测/（（毛需求-安全预测）/6），这除以6是什么意思？
                                     2) safe_month,
                               round((nvl(t4.tot_gross, 0) - nvl(t4.tactic, 0)) / 6) aver_gross,
                               -- TODO 储备月怀疑有问题
                               CASE
                                 WHEN nvl(round(((nvl(t4.tot_gross, 0) -
                                                nvl(t4.tactic, 0)) / 6),
                                                1),
                                          0) = 0 THEN
                                  0
                                 ELSE
                                  round((nvl(t4.safe_inv, 0) /
                                        ((nvl(t4.tot_gross, 0) -
                                        nvl(t4.tactic, 0)) / 6)),
                                        1)
                               END safeinv_month,
                               CASE
                                 WHEN t4.purchase_attribute = 'VMI' THEN
                                  (SELECT SUM(iv.safe_inventory)
                                     FROM apsuser.item_safe_inventory iv
                                    WHERE iv.inventory_item_id =
                                          t4.inventory_item_id
                                      AND iv.organization_id =
                                          t4.organization_id)
                                 ELSE
                                  (SELECT msib.inv_level
                                     FROM apsuser.mtl_system_items_b@fssnew msib
                                    WHERE msib.inventory_item_id =
                                          t4.inventory_item_id
                                      AND msib.organization_id =
                                          t4.organization_id
                                      AND rownum = 1)
                               END inv_level
                          FROM (SELECT t1.*,
                                       nvl(t2.m0, 0) m0,
                                       nvl(t2.m1, 0) m1,
                                       nvl(t2.m2, 0) m2,
                                       nvl(t2.m3, 0) m3,
                                       nvl(t2.m4, 0) m4,
                                       nvl(t2.m5, 0) m5,
                                       nvl(t2.m6, 0) m6,
                                       nvl(t2.m7, 0) m7,
                                       nvl(t2.m8, 0) m8,
                                       nvl(t2.m9, 0) m9,
                                       nvl(t2.m10, 0) m10,
                                       nvl(t2.m11, 0) m11,
                                       nvl(t2.m12, 0) m12,
                                       nvl(t2.m13, 0) m13,
                                       nvl(t2.m14, 0) m14,
                                       nvl(t2.m15, 0) m15,
                                       nvl(t2.m16, 0) m16,
                                       nvl(t2.m17, 0) m17,
                                       nvl(t2.m18, 0) m18,
                                       nvl(t2.m19, 0) m19,
                                       nvl(t2.m20, 0) m20,
                                       nvl(t2.m21, 0) m21,
                                       nvl(t2.m22, 0) m22,
                                       nvl(t2.m23, 0) m23,
                                       nvl(t2.m24, 0) m24,
                                       nvl(t2.m25, 0) m25,
                                       nvl(t2.m26, 0) m26,
                                       nvl(t2.m27, 0) m27,
                                       nvl(t2.m28, 0) m28,
                                       nvl(t2.m29, 0) m29,
                                       nvl(t2.m30, 0) m30,
                                       nvl(t2.m31, 0) m31,
                                       nvl(t2.m32, 0) m32,
                                       nvl(t2.m33, 0) m33,
                                       nvl(t2.m34, 0) m34,
                                       nvl(t2.m35, 0) m35,
                                       nvl(t2.m36, 0) m36,
                                       nvl(t2.tot_gross, 0) tot_gross,
                                       nvl(t2.erp_gross, 0) erp_gross
                                  FROM (SELECT b.*,
                                               nvl(t.good_qty_not_vmi, 0) good_qty_not_vmi,
                                               nvl(t.good_qty_with_vmi, 0) good_qty_with_vmi,
                                               nvl(t.good_qty_with_vmi_over_date,
                                                   0) good_qty_with_vmi_over_date,
                                               nvl(t.good_qty_with_vmi_locked, 0) good_qty_with_vmi_locked,
                                               nvl(t.bad_qty, 0) bad_qty,
                                               nvl(t.sx, 0) sx
                                          FROM item_temp b
                                          FULL JOIN storage_temp t
                                            ON (b.inventory_item_id =
                                               t.inventory_item_id AND
                                               b.scheduling_organization_id =
                                               t.scheduling_organization_id)) t1
                                  FULL JOIN gross_temp t2
                                    ON (t1.inventory_item_id =
                                       t2.inventory_item_id AND
                                       t1.scheduling_organization_id =
                                       t2.scheduling_organization_id)) t4
                        
                          FULL JOIN po_temp t3
                            ON (t4.inventory_item_id = t3.inventory_item_id AND
                               t4.scheduling_organization_id =
                               t3.scheduling_organization_id)) g) g2
          FULL JOIN fss_temp t1
            ON (t1.inventory_item_id = g2.inventory_item_id AND
               t1.scheduling_organization_id =
               g2.scheduling_organization_id)) g3
 WHERE nvl(g3.good_qty_not_vmi, 0) + nvl(g3.good_qty_with_vmi, 0) +
       nvl(g3.good_qty_with_vmi_over_date, 0) + nvl(g3.stock_qty, 0) +
       nvl(g3.bad_qty, 0) + nvl(g3.sx, 0) + nvl(g3.wip, 0) +
       nvl(g3.safe_inv, 0) + nvl(g3.tot_gross, 0) + nvl(g3.erp_gross, 0) +
       nvl(g3.tot_po, 0) + nvl(g3.pr_qty, 0) + nvl(g3.tot_po, 0) +
       nvl(g3.fss_gross, 0) + nvl(g3.pr_qty, 0) > 0
