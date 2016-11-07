module Solution
  class SportVideoHelper
    VIDEOS = {
      "茉雅减肥操" => {
        title: "茉雅减肥操",
        image: 'http://up.boohee.cn/house/u/nice/sport_video_images/茉雅减肥操.jpg',
        time: 54,
        link: 'http://v.youku.com/v_show/id_XNjQ1MTgzNzIw.html?beta&f=27160461&o=0&spm=0.0.playList.5~5~A.fnuRTc'
      },
      "XHIT腿腹循环" => {
        title: "XHIT腿腹循环",
        image: 'http://up.boohee.cn/house/u/nice/sport_video_images/XHIT腿腹循环.jpg',
        time: 9,
        link: 'http://v.youku.com/v_show/id_XNjA3MjA0MDIw.html?beta&from=s1.8-1-1.2&spm=0.0.0.0.jTv6Dh'
      },
      "郑多燕小红帽" => {
        title: "郑多燕小红帽",
        image: 'http://up.boohee.cn/house/u/nice/sport_video_images/郑多燕小红帽.jpg',
        time: 37,
        link: 'http://v.qq.com/x/page/v0148s0ar1p.html'
      },
      "Pump it up 2005" => {
        title: "Pump it up 2005",
        image: 'http://up.boohee.cn/house/u/nice/sport_video_images/pump_it_up2005.jpg',
        time: 58,
        link: 'http://v.youku.com/v_show/id_XMTQ1MDg5NzY3Mg==.html?beta&f=26568325&o=0&spm=0.0.playList.5!2~5~A.dCfwUJ'
      },
      "Pump it up 2004" => {
        title: "Pump it up 2004",
        image: 'http://up.boohee.cn/house/u/nice/sport_video_images/pump_it_up2004.jpg',
        time: 77,
        link: 'http://v.youku.com/v_show/id_XMTQ1MDg4ODAwOA==.html?beta&f=26568325&o=0&spm=0.0.playList.5~5~A.dCfwUJ'
      },
      "超模25健身操I" => {
        title: "超模25健身操I",
        image: 'http://up.boohee.cn/house/u/nice/sport_video_images/超模I.jpg',
        time: 24,
        link: 'http://v.qq.com/x/page/g0177ndi7u3.html'
      },
      "超模25健身操II" => {
        title: "超模25健身操II",
        image: 'http://up.boohee.cn/house/u/nice/sport_video_images/超模II.jpg',
        time: 26,
        link: 'http://v.qq.com/x/page/z03008ff6bk.html'
      },
      "XHIT全身燃脂" => {
        title: "XHIT全身燃脂",
        image: 'http://up.boohee.cn/house/u/nice/sport_video_images/XHIT全身燃脂.jpg',
        time: 18,
        link: 'http://v.youku.com/v_show/id_XNjQ0MDAwMjc2.html?beta&from=s1.8-1-1.2&spm=0.0.0.0.6mDbXJ'
      },
      "快走45" => {
        image: 'http://up.boohee.cn/house/u/nice/sport_video_images/快走.jpg',
        time: 45,
        title: '快走'
      },
      "快走60" => {
        image: 'http://up.boohee.cn/house/u/nice/sport_video_images/快走.jpg',
        time: 60,
        title: '快走'
      },
      "慢跑45" => {
        image: 'http://up.boohee.cn/house/u/nice/sport_video_images/慢跑.jpg',
        time: 45,
        title: '慢跑'
      },
      "慢跑60" => {
        image: 'http://up.boohee.cn/house/u/nice/sport_video_images/慢跑.jpg',
        time: 60,
        title: '慢跑'
      },
      "走跑结合45" => {
        image: 'http://up.boohee.cn/house/u/nice/sport_video_images/慢跑.jpg',
        title: '走跑结合',
        time: 45
      }

    }

    SPORT_VIDEO_HASH = {
      "肥胖/运动受限-倒班-健身房运动-运动不足" => ['快走45'],
      "肥胖/运动受限-倒班-健身房运动-运动" => ['快走60'],
      "肥胖/运动受限-倒班-小区操场运动-运动不足" => ['快走45', '茉雅减肥操'],
      "肥胖/运动受限-倒班-小区操场运动-运动" => ['快走60', '茉雅减肥操', 'XHIT腿腹循环'],
      "肥胖/运动受限-倒班-家里运动或其它-运动不足" => ['茉雅减肥操', 'XHIT腿腹循环'],
      "肥胖/运动受限-倒班-家里运动或其它-运动" => ['茉雅减肥操', 'XHIT腿腹循环'],
      "肥胖/运动受限-没时间运动-健身房运动-运动不足" => ['快走45', '茉雅减肥操'],
      "肥胖/运动受限-没时间运动-健身房运动-运动" => ['快走60', '茉雅减肥操'],
      "肥胖/运动受限-没时间运动-小区操场运动-运动不足" => ['快走45', '茉雅减肥操'],
      "肥胖/运动受限-没时间运动-小区操场运动-运动" => ['快走60', '茉雅减肥操'],
      "肥胖/运动受限-没时间运动-家里运动或其它-运动不足" => ['茉雅减肥操', '郑多燕小红帽'],
      "肥胖/运动受限-没时间运动-家里运动或其它-运动" => ['茉雅减肥操', '郑多燕小红帽'],
      "肥胖/运动受限-晚上运动/上午运动/下午运动-健身房运动-运动不足" => ['快走45', '茉雅减肥操'],
      "肥胖/运动受限-晚上运动/上午运动/下午运动-健身房运动-运动" => ['快走60', '茉雅减肥操'],
      "肥胖/运动受限-晚上运动/上午运动/下午运动-小区操场运动-运动不足" => ['快走45', '茉雅减肥操'],
      "肥胖/运动受限-晚上运动/上午运动/下午运动-小区操场运动-运动" => ['快走60', '茉雅减肥操'],
      "肥胖/运动受限-晚上运动/上午运动/下午运动-家里运动或其它-运动不足" => ['茉雅减肥操', '郑多燕小红帽'],
      "肥胖/运动受限-晚上运动/上午运动/下午运动-家里运动或其它-运动" => ['茉雅减肥操', '郑多燕小红帽'],
      "肥胖/运动受限-早餐前运动-健身房运动-运动不足" => ['快走45', '茉雅减肥操'],
      "肥胖/运动受限-早餐前运动-健身房运动-运动" => ['快走60', '茉雅减肥操'],
      "肥胖/运动受限-早餐前运动-小区操场运动-运动不足" => ['快走45', '茉雅减肥操'],
      "肥胖/运动受限-早餐前运动-小区操场运动-运动" => ['快走60', '茉雅减肥操'],
      "肥胖/运动受限-早餐前运动-家里运动或其它-运动不足" => ['茉雅减肥操', '郑多燕小红帽'],
      "肥胖/运动受限-早餐前运动-家里运动或其它-运动" => ['茉雅减肥操', '郑多燕小红帽'],
      "超重/大体重-倒班-健身房运动-运动不足" => ['慢跑45', 'Pump it up 2005'],
      "超重/大体重-倒班-健身房运动-运动" => ['慢跑60', 'Pump it up 2005'],
      "超重/大体重-倒班-小区操场运动-运动不足" => ['慢跑45', 'Pump it up 2005', 'XHIT腿腹循环'],
      "超重/大体重-倒班-小区操场运动-运动" => ['慢跑60', 'Pump it up 2005', 'XHIT腿腹循环'],
      "超重/大体重-倒班-家里运动或其它-运动不足" => ['Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "超重/大体重-倒班-家里运动或其它-运动" => ['Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "超重/大体重-没时间运动-健身房运动-运动不足" => ['慢跑45', 'Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "超重/大体重-没时间运动-健身房运动-运动" => ['慢跑60', 'Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "超重/大体重-没时间运动-小区操场运动-运动不足" => ['走跑结合45', 'Pump it up 2005', '超模25健身操I'],
      "超重/大体重-没时间运动-小区操场运动-运动" => ['慢跑60', 'Pump it up 2005', '超模25健身操I'],
      "超重/大体重-没时间运动-家里运动或其它-运动不足" => ['Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "超重/大体重-没时间运动-家里运动或其它-运动" => ['Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "超重/大体重-晚上运动/上午运动/下午运动-健身房运动-运动不足" => ['慢跑45', 'Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "超重/大体重-晚上运动/上午运动/下午运动-健身房运动-运动" => ['慢跑60', 'Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "超重/大体重-晚上运动/上午运动/下午运动-小区操场运动-运动不足" => ['慢跑45', 'Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "超重/大体重-晚上运动/上午运动/下午运动-小区操场运动-运动" => ['慢跑60', 'Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "超重/大体重-晚上运动/上午运动/下午运动-家里运动或其它-运动不足" => ['Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "超重/大体重-晚上运动/上午运动/下午运动-家里运动或其它-运动" => ['Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "超重/大体重-早餐前运动-健身房运动-运动不足" => ['慢跑45', 'Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "超重/大体重-早餐前运动-健身房运动-运动" => ['慢跑60', 'Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "超重/大体重-早餐前运动-小区操场运动-运动不足" => ['慢跑45', 'Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "超重/大体重-早餐前运动-小区操场运动-运动" => ['慢跑60', 'Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "超重/大体重-早餐前运动-家里运动或其它-运动不足" => ['Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "超重/大体重-早餐前运动-家里运动或其它-运动" => ['Pump it up 2005', '超模25健身操I', 'XHIT腿腹循环'],
      "中体重/小体重/轻体重-倒班-健身房运动-运动不足" => ['慢跑45', 'Pump it up 2004', '超模25健身操II'],
      "中体重/小体重/轻体重-倒班-健身房运动-运动" => ['慢跑60', 'Pump it up 2004', '超模25健身操II'],
      "中体重/小体重/轻体重-倒班-小区操场运动-运动不足" => ['慢跑45', 'Pump it up 2004', '超模25健身操II'],
      "中体重/小体重/轻体重-倒班-小区操场运动-运动" => ['慢跑60', 'Pump it up 2004', '超模25健身操II'],
      "中体重/小体重/轻体重-倒班-家里运动或其它-运动不足" => ['Pump it up 2004', '超模25健身操II', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-倒班-家里运动或其它-运动" => ['Pump it up 2004', '超模25健身操II', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-没时间运动-健身房运动-运动不足" => ['慢跑45', '超模25健身操II', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-没时间运动-健身房运动-运动" => ['慢跑60', '超模25健身操II', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-没时间运动-小区操场运动-运动不足" => ['慢跑45', '超模25健身操II', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-没时间运动-小区操场运动-运动" => ['慢跑60', '超模25健身操II', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-没时间运动-家里运动或其它-运动不足" => ['超模25健身操I', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-没时间运动-家里运动或其它-运动" => ['超模25健身操I', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-晚上运动/上午运动/下午运动-健身房运动-运动不足" => ['慢跑45', '超模25健身操II', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-晚上运动/上午运动/下午运动-健身房运动-运动" => ['慢跑60', '超模25健身操II', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-晚上运动/上午运动/下午运动-小区操场运动-运动不足" => ['慢跑45', '超模25健身操II', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-晚上运动/上午运动/下午运动-小区操场运动-运动" => ['慢跑60', '超模25健身操II', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-晚上运动/上午运动/下午运动-家里运动或其它-运动不足" => ['Pump it up 2004', '超模25健身操II', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-晚上运动/上午运动/下午运动-家里运动或其它-运动" => ['Pump it up 2004', '超模25健身操II', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-早餐前运动-健身房运动-运动不足" => ['慢跑45', '超模25健身操II', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-早餐前运动-健身房运动-运动" => ['慢跑60', '超模25健身操II', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-早餐前运动-小区操场运动-运动不足" => ['慢跑45', '超模25健身操II', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-早餐前运动-小区操场运动-运动" => ['慢跑60', '超模25健身操II', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-早餐前运动-家里运动或其它-运动不足" => ['超模25健身操I', 'XHIT全身燃脂'],
      "中体重/小体重/轻体重-早餐前运动-家里运动或其它-运动" => ['超模25健身操I', 'XHIT全身燃脂']
    }

    def self.get(code)
      sport_names = SPORT_VIDEO_HASH[code]
      sport_names.map { |n| VIDEOS[n] }
    end
  end
end