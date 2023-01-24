--trigger，自动更新修改时间
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_update_date = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 期号表
CREATE TABLE plan.inv_exc_nos (
	forecast_id varchar(32) NOT NULL, -- 预测期号ID
	forecast_no varchar(32) NOT NULL, -- 预测期号
	scheduling_org_id numeric not NULL, -- 排产组织id
	created_by varchar(40) NOT NULL, -- 创建人
	creation_date timestamp NOT NULL  DEFAULT now(), -- 创建时间
	last_updated_by varchar(40) NOT NULL, -- 修改人
	last_update_date timestamp NOT NULL DEFAULT now() -- 修改时间
);
--更新数据时更新修改时间
CREATE TRIGGER last_update_date BEFORE UPDATE ON plan.inv_exc_nos FOR EACH ROW EXECUTE PROCEDURE  update_modified_column();

COMMENT ON TABLE plan.inv_exc_nos IS '期号表';
COMMENT ON COLUMN plan.inv_exc_nos.forecast_id IS '预测期号ID';
COMMENT ON COLUMN plan.inv_exc_nos.forecast_no IS '预测期号';
COMMENT ON COLUMN plan.inv_exc_nos.scheduling_org_id IS '排产组织id';
COMMENT ON COLUMN plan.inv_exc_nos.created_by IS '创建人';
COMMENT ON COLUMN plan.inv_exc_nos.creation_date IS '创建时间';
COMMENT ON COLUMN plan.inv_exc_nos.last_updated_by IS '修改人';
COMMENT ON COLUMN plan.inv_exc_nos.last_update_date IS '修改时间';

--库存监控基础信息
create table plan.inv_exc_basic_info (
	forecast_id VARCHAR(32) NOT NULL, -- 预测期号
	item VARCHAR(150), --	编码
	inventory_item_id numeric, -- 编码id
	supply_type VARCHAR(255),--	供应类型
	wip numeric ,--在制
	wip_all numeric ,--总在制含所有非标
	pre_over numeric ,--三十天内即将超期
	continuity_reserve_target numeric ,--连续性储备目标
	safety_stock_objectives numeric ,--安全库存目标
	mpq numeric,--	最小包装量
	moq numeric,--	最小订单量
	inventory_level_target numeric,--	库存水位目标
	continuity_inv numeric,--	连续性库存
	measurement_unit VARCHAR(3),--	单位uom
	total_pr numeric,--	Pr总量
	reserve_identification varchar(40),	-- 储备标识
	reserve_cancellation varchar(40),	-- 储备取消
	warn_info	VARCHAR(40),	-- 预警信息
	inv_alert	VARCHAR(40),		-- 库存异常
	created_by varchar(40) NOT NULL, -- 创建人
	creation_date timestamp NOT NULL  DEFAULT now(), -- 创建时间
	last_updated_by varchar(40) NOT NULL, -- 修改人
	last_update_date timestamp NOT NULL DEFAULT now() -- 修改时间
);
CREATE TRIGGER last_update_date BEFORE UPDATE ON plan.inv_exc_basic_info FOR EACH ROW EXECUTE PROCEDURE  update_modified_column();
COMMENT ON TABLE plan.inv_exc_basic_info IS '库存监控基础信息';
COMMENT ON COLUMN plan.inv_exc_basic_info.forecast_id IS '预测期号ID';
COMMENT ON COLUMN plan.inv_exc_basic_info.item IS '编码';
COMMENT ON COLUMN plan.inv_exc_basic_info.inventory_item_id IS '编码id';
COMMENT ON COLUMN plan.inv_exc_basic_info.supply_type IS '供应类型';
COMMENT ON COLUMN plan.inv_exc_basic_info.wip IS '在制';
COMMENT ON COLUMN plan.inv_exc_basic_info.wip_all IS '总在制含所有非标';
COMMENT ON COLUMN plan.inv_exc_basic_info.pre_over IS '三十天内即将超期';
COMMENT ON COLUMN plan.inv_exc_basic_info.continuity_reserve_target IS '连续性储备目标';
COMMENT ON COLUMN plan.inv_exc_basic_info.safety_stock_objectives IS '安全库存目标';
COMMENT ON COLUMN plan.inv_exc_basic_info.mpq IS '最小包装量';
COMMENT ON COLUMN plan.inv_exc_basic_info.moq IS '最小订单量';
COMMENT ON COLUMN plan.inv_exc_basic_info.inventory_level_target IS '库存水位目标';
COMMENT ON COLUMN plan.inv_exc_basic_info.continuity_inv IS '连续性库存';
COMMENT ON COLUMN plan.inv_exc_basic_info.measurement_unit IS '单位uom';
COMMENT ON COLUMN plan.inv_exc_basic_info.total_pr IS 'PR总量';
COMMENT ON COLUMN plan.inv_exc_basic_info.reserve_identification IS '储备标识';
COMMENT ON COLUMN plan.inv_exc_basic_info.reserve_cancellation IS '储备取消';
COMMENT ON COLUMN plan.inv_exc_basic_info.warn_info IS '预警信息';
COMMENT ON COLUMN plan.inv_exc_basic_info.inv_alert IS '库存异常';
COMMENT ON COLUMN plan.inv_exc_basic_info.created_by IS '创建人';
COMMENT ON COLUMN plan.inv_exc_basic_info.creation_date IS '创建时间';
COMMENT ON COLUMN plan.inv_exc_basic_info.last_updated_by IS '修改人';
COMMENT ON COLUMN plan.inv_exc_basic_info.last_update_date IS '修改时间';

--毛需求po信息表
CREATE TABLE plan.inv_exc_gross_po_info (
	forecast_id	VARCHAR(32) NOT NULL,	-- 预测期号id
	inventory_item_id	numeric,	-- 编码id
	data_type varchar(10),	-- 数据类型gross/po
	-- 每月毛需求数量或者po数量，类型为po时取前12个
	m0	numeric default(0), 
	m1	numeric default(0), 
	m2	numeric default(0), 
	m3	numeric default(0), 
	m4	numeric default(0), 
	m5	numeric default(0), 
	m6	numeric default(0), 
	m7	numeric default(0), 
	m8	numeric default(0), 
	m9	numeric default(0), 
	m10	numeric default(0), 
	m11	numeric default(0), 
	m12	numeric default(0), 
	m13	numeric default(0), 
	m14	numeric default(0), 
	m15	numeric default(0), 
	m16	numeric default(0), 
	m17	numeric default(0), 
	m18	numeric default(0), 
	m19	numeric default(0), 
	m20	numeric default(0), 
	m21	numeric default(0), 
	m22	numeric default(0), 
	m23	numeric default(0), 
	m24	numeric default(0), 
	m25	numeric default(0), 
	m26	numeric default(0), 
	m27	numeric default(0), 
	m28	numeric default(0), 
	m29	numeric default(0), 
	m30	numeric default(0), 
	m31	numeric default(0), 
	m32	numeric default(0), 
	m33	numeric default(0), 
	m34	numeric default(0), 
	m35	numeric default(0), 
	m36	numeric default(0), 
	created_by varchar(40) NOT NULL, -- 创建人
	creation_date timestamp NOT NULL  DEFAULT now(), -- 创建时间
	last_updated_by varchar(40) NOT NULL, -- 修改人
	last_update_date timestamp NOT NULL DEFAULT now() -- 修改时间
);
CREATE TRIGGER last_update_date BEFORE UPDATE ON plan.inv_exc_gross_po_info FOR EACH ROW EXECUTE PROCEDURE  update_modified_column();
COMMENT ON TABLE plan.inv_exc_gross_po_info IS '毛需求po信息表';
COMMENT ON COLUMN plan.inv_exc_gross_po_info.forecast_id IS '预测期号ID';
COMMENT ON COLUMN plan.inv_exc_gross_po_info.inventory_item_id IS '编码id';
COMMENT ON COLUMN plan.inv_exc_gross_po_info.m0 IS '月毛需求数量或者po数量，类型为po时取12个';
COMMENT ON COLUMN plan.inv_exc_gross_po_info.created_by IS '创建人';
COMMENT ON COLUMN plan.inv_exc_gross_po_info.creation_date IS '创建时间';
COMMENT ON COLUMN plan.inv_exc_gross_po_info.last_updated_by IS '修改人';
COMMENT ON COLUMN plan.inv_exc_gross_po_info.last_update_date IS '修改时间';

--库存信息表
CREATE TABLE plan.inv_exc_storage_info(	
	forecast_id	VARCHAR(32) , --	预测期号
	inventory_item_id	numeric, --	编码id
	good_qty_not_vmi	numeric default(0), --	良品库存本地
	good_qty_with_vmi	numeric default(0), --	良品库存含vmi
	good_qty_with_vmi_over_date	numeric default(0), --	良品库存超期含vmi
	good_qty_with_vmi_locked	numeric default(0), --	锁定库存
	bad_inv	numeric default(0), --	故障品库存
	repair_inv	numeric default(0), --	送修库存
	created_by varchar(40) NOT NULL, -- 创建人
	creation_date timestamp NOT NULL  DEFAULT now(), -- 创建时间
	last_updated_by varchar(40) NOT NULL, -- 修改人
	last_update_date timestamp NOT NULL DEFAULT now() -- 修改时间
);
CREATE TRIGGER last_update_date BEFORE UPDATE ON plan.inv_exc_storage_info FOR EACH ROW EXECUTE PROCEDURE  update_modified_column();
COMMENT ON TABLE plan.inv_exc_storage_info IS '库存信息表';
COMMENT ON COLUMN plan.inv_exc_storage_info.forecast_id IS '预测期号ID';
COMMENT ON COLUMN plan.inv_exc_storage_info.inventory_item_id IS '编码id';
COMMENT ON COLUMN plan.inv_exc_storage_info.good_qty_not_vmi IS '良品库存本地';
COMMENT ON COLUMN plan.inv_exc_storage_info.good_qty_with_vmi IS '良品库存含vmi';
COMMENT ON COLUMN plan.inv_exc_storage_info.good_qty_with_vmi_over_date IS '良品库存超期含vmi';
COMMENT ON COLUMN plan.inv_exc_storage_info.good_qty_with_vmi_locked IS '锁定库存';
COMMENT ON COLUMN plan.inv_exc_storage_info.bad_inv IS '故障品库存';
COMMENT ON COLUMN plan.inv_exc_storage_info.repair_inv IS '送修库存';
COMMENT ON COLUMN plan.inv_exc_storage_info.created_by IS '创建人';
COMMENT ON COLUMN plan.inv_exc_storage_info.creation_date IS '创建时间';
COMMENT ON COLUMN plan.inv_exc_storage_info.last_updated_by IS '修改人';
COMMENT ON COLUMN plan.inv_exc_storage_info.last_update_date IS '修改时间';

--赋予权限
GRANT select ON TABLE plan.inv_exc_nos TO pub_sdspg_query;
GRANT select ON TABLE plan.inv_exc_basic_info TO pub_sdspg_query;
GRANT select ON TABLE plan.inv_exc_gross_po_info TO pub_sdspg_query;
GRANT select ON TABLE plan.inv_exc_storage_info TO pub_sdspg_query;
