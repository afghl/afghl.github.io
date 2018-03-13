# -*- coding: utf-8 -*-

import os
import sys
import datetime
import logging
import time
import json

from sqlalchemy.exc import SQLAlchemyError


from ers.models import (
    City,
    CloseRestaurantWhitelist,
    DBSession,
    ShopDBSession,
    ShopDBAltSession,
    ClRestaurant,
    Restaurant,
    RestaurantTagInfo,
    RestaurantChangeRecord,
    RestaurantMultiPeriod,
    SaasStatus,
    Region,
    RegionGroup,
    RestaurantRegion,
    OperationRemind,
    RestaurantStatusRecord,
    RestaurantDirector,
    commit_deco,
    operation_commit_deco,
    RestaurantChangeInfo,
    RestaurantDeliveryAreaTypeChangeRecord,
    ShopPunishment
)
from ers import ers_thrift
from ers.dispatcher import ElemeRestaurantDispatcher as ers_client

ers = ers_client()

from zeus_core.gzs import get_gzs_client
from zeus_core.tracker import ZeusTracker
from pygzsdev import SHARDING_KEY
gzs_client = get_gzs_client()


from zeus_core.gzs import get_gzs_client
from zeus_core.tracker import ZeusTracker
from pygzsdev import SHARDING_KEY
gzs_client = get_gzs_client()

console = logging.StreamHandler()
console.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s %(filename)s[line:%(lineno)d] %(levelname)8s - %(message)s')
console.setFormatter(formatter)
logging.getLogger("").addHandler(console)
reload(sys)
sys.setdefaultencoding('utf-8')


########
# Helper
########

##################################
# set_restaurant_is_valid_false
##################################
def validate_deliver_geojson():
    shop_session = ShopDBSession()
    id_cursor = 0
    limit = 500
    count = 0
    loop_times = 0
    exec_times = 0
    update_count = 0

    while 1:
        try:
            restaurants = shop_session.query(Restaurant). \
                filter(Restaurant.id >= id_cursor). \
                order_by(Restaurant.id). \
                limit(limit). \
                all()
            if not restaurants:
                logging.info('[Restaurant] Finished')
                break
            for rst in restaurants:
                if rst.type == 100 or rst.is_valid == 0:
                    continue
                _check_deliver_geojson_and_log(rst)
            id_cursor = restaurants[-1].id + 1
            print id_cursor
        except Exception as e:
            logging.error(e)
            if exec_times == 5:
                break
            exec_times += 1
            time.sleep(60)
            continue


def _check_deliver_geojson_and_log(rst):
    try:
        ers.validate_delivery_geojson(-1, rst.deliver_geojson)
    except Exception as e:
        write_errors_to_file(rst.id, e.message)


def write_errors_to_file(id, message):
    file_name = '/home/dev/junyao.chen/deliver_geojson_error_log'
    f = file(file_name, 'a+')
    f.write('%s,%s' % (id, message))
    f.write('\n')
    f.close()

def main():
    start_time = datetime.datetime.now()
    logging.info('validate_deliver_geojson starts at: %s' % str(start_time))
    validate_deliver_geojson()
    end_time = datetime.datetime.now()
    logging.info('validate_deliver_geojson end, SECONDS:%s' % str((end_time - start_time).seconds))

if __name__ == '__main__':
    main()
