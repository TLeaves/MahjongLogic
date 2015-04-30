-- 更新历史
-- 2014.9.19    小弘 测试了四川麻将各种胡法
-- 2014.9.20    jim  更新了ValidHu()中ValidAA()的限制条件，修复了112233的情况
-- 2014.9.26    小弘 更新了三元牌的检测，用于加番计算。
-- 2014.10.28   小弘 添加广东麻将AI出牌边界限定
-- 2014.10.30   小弘 添加四川麻将听牌检测Beta，未合并重复项（未充分测试）
-- 2014.10.31   小弘 进一步完善四川麻将听牌，已合并重复项
-- 2015.1.23    小弘 把weight评估值从取最小值修改为负数值之和，使评估更完善，从而修复此前AI不能杠的情况。
--                   并且添加AI出牌阶段的分级模式，使其一定概率随意出牌，AI从强到弱依次是0,1,2,3级
-- 2015.1.27    小弘 修复一个因为吃碰杠中因为没有对手牌排序而导致的无法转换出序号的bug，在转换前加了一个排序。
--                   还有把AI出牌里剔除非手牌的操作提到最前。
-- 2015.3.10    小弘 合并大量重复的代码，新增一堆注释，未完全测试
-- 2015.3.11    小弘 修改了暗杠

----------------------- 广东麻将胡法 -------------------
--CheckJH()    --鸡胡     什么牌都可以胡，可吃碰杠
--CheckPH()    --平胡     全部都是顺子没有刻子
--CheckPPH()   --碰碰胡   全部是刻子没有顺子
--CheckHYS()   --混一色   整副牌由字牌及另外单一花色（筒、条或万）组成
--CheckQYS()   --清一色   整副牌由同一花色组成
--CheckHP()    --碰混     混一色 + 碰碰胡
--CheckQP()    --清碰     清一色 + 碰碰胡
--CheckHYJ()   --混幺九   由幺九牌和字牌组成的牌型
--CheckXSY()   --小三元   拿齐中、发、白三种三元牌，但其中一种是将
--CheckXSX()   --小四喜   胡牌者完成东、南、西、北其中三组刻子，一组对子
--CheckZYS()   --字一色   由字牌组合成的刻子牌型
--CheckQYJ()   --清幺九   只由幺九两种牌组成的刻子牌型
--CheckDSX()   --大三元   胡牌时，有中、发、白三组刻子
--CheckDSX()   --大四喜   胡牌者完成东、南、西、北四组刻子
--CheckJLBD()  --九莲宝灯 同种牌形成 1112345678999 ，在摸到该种牌任何一张即可胡牌，不计清一色
--CheckSSY()   --十三幺   1 、 9 万筒索，东、南、西、北、中、发、白；以上牌型任意一张牌作将

----------------------- 四川麻将胡法 -------------------
-- CheckPh_SC()   --平胡    普通的四个搭子一对将
-- CheckDdz_SC()  --大对子  四个搭子均为三张一样的牌
-- CheckQys_SC()  --清一色  胡牌时只有一色牌
-- CheckDy_SC()   --带幺    所有牌都带1或9
-- CheckAqd_SC()  --暗七对  特殊胡牌类型，不遵循四个搭子一对将，胡牌时为7个对子
-- CheckQdd_SC()  --清大对  清一色+大对子
-- CheckLqd_SC()  --龙七对  暗七对的改进，七对中有两对（或更多）相同，可视作带根的暗七对。
-- CheckQqd_SC()  --清七对  清一色+暗七对
-- CheckQdy_SC()  --清带幺  清一色+带幺
-- CheckQlqd_SC() --清龙七对  清一色+龙七对

local MJ_WAN       = 1    --万
local MJ_TIAO      = 2    --条
local MJ_BING      = 3    --饼
local MJ_FENG      = 4    --东南西北(1357)
local MJ_ZFB       = 5    --中发白(135)

local Pai_MING     = 0    --明
local Pai_AN       = 1    --暗

local Pai_My       = 0    --手牌组
local Pai_Chi      = 1    --吃牌组
local Pai_Peng     = 2    --碰牌组
local Pai_Gang     = 3    --杠牌组
local Pai_Ting     = 4    --听牌组

math.randomseed(tostring(os.time()):reverse():sub(1,6))

--检查牌的明暗或者空
local function CheckSinglePaiMingAn(pai)
  return math.floor(pai%10000/1000)
end

--检查单张牌所属牌组
local function CheckSinglePaiGroup(pai)
  return math.floor(pai%1000/100)
end

--检查单张牌的类型，万饼筒条
local function CheckSinglePaiType(pai)
  return math.floor(pai%100/10)
end

--检查单张牌的数值
local function CheckSinglePaiNum(pai)
  return math.floor(pai%10)
end

--返回标准牌型数值(包括牌型与数字)
local function GetPaiTypeNum(pai)
  return math.floor(pai%100)
end

--检测一对
local function CheckAAPai(iValue1,iValue2)
    if iValue1 == iValue2 then return true
    else return false
    end
end

--检测三连张
local function CheckABCPai(iValue1,iValue2,iValue3)
    if (iValue1 == iValue2-1)and(iValue2 == iValue3-1) then return true
    else return false
    end
end

--检测三重张
local function CheckAAAPai(iValue1,iValue2,iValue3)
    local p12 = CheckAAPai(iValue1,iValue2)
    local p23 = CheckAAPai(iValue2,iValue3)
    if p12 and p23 then return true
    else return false
    end
end

-- 将用户的牌分成 万，条，饼，风，中发白五组并排序返回
local function SortByType(userPai)
  local sort_pai = {
            ["My"]  =  {
                  [MJ_WAN] = {},
                  [MJ_TIAO] = {},
                  [MJ_BING] = {},
                  [MJ_FENG] = {},
                  [MJ_ZFB] = {}
                  },--手牌组
            ["Chi"] = {
                  [MJ_WAN] = {},
                  [MJ_TIAO] = {},
                  [MJ_BING] = {},
                  [MJ_FENG] = {},
                  [MJ_ZFB] = {}
                  },--吃牌组
            ["Peng"] = {
                  [MJ_WAN] = {},
                  [MJ_TIAO] = {},
                  [MJ_BING] = {},
                  [MJ_FENG] = {},
                  [MJ_ZFB] = {}
                  },--碰牌组
            ["Gang"] = {
                  [MJ_WAN] = {},
                  [MJ_TIAO] = {},
                  [MJ_BING] = {},
                  [MJ_FENG] = {},
                  [MJ_ZFB] = {}
                  },--杠牌组
            ["Ting"] = {
                  [MJ_WAN] = {},
                  [MJ_TIAO] = {},
                  [MJ_BING] = {},
                  [MJ_FENG] = {},
                  [MJ_ZFB] = {}
                  }--听牌组
          }
  for i = 1,#userPai,1 do
    if CheckSinglePaiGroup(userPai[i]) == Pai_My then
      local paiType = CheckSinglePaiType(userPai[i])
      table.insert(sort_pai["My"][paiType],userPai[i])
    end
    if CheckSinglePaiGroup(userPai[i]) == Pai_Chi then
      local paiType = CheckSinglePaiType(userPai[i])
      table.insert(sort_pai["Chi"][paiType],userPai[i])
    end
    if CheckSinglePaiGroup(userPai[i]) == Pai_Peng then
      local paiType = CheckSinglePaiType(userPai[i])
      table.insert(sort_pai["Peng"][paiType],userPai[i])
    end
    if CheckSinglePaiGroup(userPai[i]) == Pai_Gang then
      local paiType = CheckSinglePaiType(userPai[i])
      table.insert(sort_pai["Gang"][paiType],userPai[i])
    end
    if CheckSinglePaiGroup(userPai[i]) == Pai_Ting then
      local paiType = CheckSinglePaiType(userPai[i])
      table.insert(sort_pai["Ting"][paiType],userPai[i])
    end
  end

  for i = 1,5,1 do
    table.sort(sort_pai["My"][i])
    table.sort(sort_pai["Chi"][i])
    table.sort(sort_pai["Peng"][i])
    table.sort(sort_pai["Gang"][i])
    table.sort(sort_pai["Ting"][i])
  end

  return sort_pai
end

--复制一副牌并返回
--提示：由于lua传递table时是传递引用，所以在函数内部修改table会影响到外部的table，因此用此函数拷贝一份table
local function CopyPai(userPai)
  local t_pai = {}
  for i = 1,#userPai do
    table.insert(t_pai,userPai[i])
  end
  return t_pai
end

--测试胡AA牌（将牌）
local function ValidAA(pai,i,n)
  if i + 1 <= n and pai[i] == pai[i+1]  then
    return true
  else
    return false
  end
end

--测试胡AAA牌（刻子）
local function ValidAAA(pai,i,n)
  if i + 2 <= n and pai[i] == pai[i+1] and pai[i] == pai[i+2] then
    return true
  else
    return false
  end
end

--测试胡ABC牌（顺子）
local function ValidABC(pai,i,n)
  -- 顺子要避开 1 222 3  这种可能组成 123 22 的情况
  -- 所以拆成两个列表  (1 2 3)|(22)
  -- 然后判断 ValidHu(22)

  local t_pai = CopyPai(pai)
  -- 只有两张牌，必定没顺
  if n - i < 2  then
    return false
  end

  local found_B = false
  local found_C = false
  for j = i+1,#t_pai,1 do
    if found_B == false and t_pai[j] == ( t_pai[i] + 1 ) then
      found_B = true
      -- 交换两张牌的位置
      local t = t_pai[i + 1]
      t_pai[i + 1] = t_pai[j]
      t_pai[j] = t
    end
  end

  for k = i + 2,#pai,1 do
    if found_C== false and t_pai[k] == ( t_pai[i] + 2 ) then
      found_C = true
      -- 交换两张牌的位置
      local t = t_pai[i + 2]
      t_pai[i + 2] = t_pai[k]
      t_pai[k] = t
    end
  end

  -- 如果能找到顺，判断剩下的牌是否能胡
  if found_B == true and found_C == true then
    -- 创建待判断列表
    local new_list = {}
    local k = 1
    for j = i + 3,#pai,1 do
      new_list[k] = t_pai[j]
      k = k + 1
    end
    -- 对新建数组进行排序
    table.sort(new_list)

    return true,new_list
  else
    return false,{nil}
  end
end

--测试胡n张牌
--IN：用户牌，检测起点，检测总数
--OUT：是否胡牌，将牌数
local function ValidHu(pai,i,n)
  -- 空牌组直接胡
  if n == 0 then
    return true,0
  end
  
  -- 存在两个将牌或少于两个牌，不可能胡
  if n%3==1 then 
    return false,0
  end

  -- 检测到末尾，胡
  if i > n then
    return true,0
  end

  -- 测试 AAA
  if ValidAAA(pai,i,n) then
    local t = false
    local k = 0
    t,k = ValidHu(pai,i+3,n,0)
    if t == true then return true,k end
  end

  -- 测试AA
  if ValidAA(pai,i,n) then
    local t = false
    local k = 0
    t,k = ValidHu(pai,i+2,n)
    if t == true and k == 0 then return true,1 end
  end

  -- 对万，条，饼测试ABC
  if CheckSinglePaiType(pai[1]) ~= MJ_FENG and CheckSinglePaiType(pai[1]) ~= MJ_ZFB then
    local new_pai = {}
    local t       = false
    t,new_pai = ValidABC(pai,i,n)
    if t == true then
      local t2 = false
      local k  = 0
      t2,k = ValidHu(new_pai,1,#new_pai)
      if t2 == true then return t2,k end
    end
  end
  return false,0
end

--检测吃牌
--IN：用户牌，上家的牌（只有上家能吃）
--OUT：所有可吃的牌的（！序号！）的table集合
--举例：手牌：11,12,12,14，上家牌：13
--   输出：{{1,2}，{2,4}}
--客户端会把序号重新转换成牌值，至于为什么这里转成序号，那是历史遗留问题。。。
function CheckChiPai(userPai,prePai)
  --吃牌，用上家牌与自身牌遍历对比
  local paiGroup = SortByType(userPai)

  local attribute = {["Chi"]={}}
  local paiType = CheckSinglePaiType(prePai)
  if(#paiGroup["My"][paiType])
  then
    for i=1,#(paiGroup["My"][paiType])-1
    do
        --上家牌在顺子最左
        if (paiGroup["My"][paiType][i] == prePai+1) and (paiGroup["My"][paiType][i+1] == prePai+2)
        then
          local shunzi = {paiGroup["My"][paiType][i],paiGroup["My"][paiType][i+1]}
          table.insert(attribute["Chi"],shunzi)
        end
        --上家牌在顺子中间
        if (paiGroup["My"][paiType][i] == prePai-1) and (paiGroup["My"][paiType][i+1] == prePai+1)
        then
          local shunzi = {paiGroup["My"][paiType][i],paiGroup["My"][paiType][i+1]}
          table.insert(attribute["Chi"],shunzi)
        --下面这块是用在出现AB**BC时吃B的情况
        elseif (paiGroup["My"][paiType][i] ==prePai-1) and (paiGroup["My"][paiType][i+1] == prePai)
        then
          for k=i+1,#(paiGroup["My"][paiType])
          do
            if (paiGroup["My"][paiType][k] == prePai+1)
            then
              local shunzi = {paiGroup["My"][paiType][i],paiGroup["My"][paiType][k]}
              table.insert(attribute["Chi"],shunzi)
            end
          end
        end 
        --上家牌在顺子最右
        if (paiGroup["My"][paiType][i] == prePai-2) and (paiGroup["My"][paiType][i+1] == prePai-1)
        then
          local shunzi = {paiGroup["My"][paiType][i],paiGroup["My"][paiType][i+1]}
          table.insert(attribute["Chi"],shunzi)
        end
    end
  end

  --转换至userPai的绝对位置
  table.sort( userPai, function (a,b) return a<b end )
  for i=1,#attribute["Chi"]
  do
    for j=1,2
    do
      for k=1,#userPai
      do
        if attribute["Chi"][i][j] == userPai[k]
        then
          attribute["Chi"][i][j] = k
        end
      end
    end
  end

  return attribute["Chi"]
end

--检测碰牌
--IN：用户牌，别人打的牌
--OUT：所有可碰的牌的（！序号！）的table集合
--输出格式与吃牌类似
function CheckPengPai(userPai,prePai)
  --碰牌
  local paiGroup = SortByType(userPai)

  local attribute = {["Peng"]={}}

  local paiType = CheckSinglePaiType(prePai)
  if(#paiGroup["My"][paiType])
  then
    for i=1,#(paiGroup["My"][paiType])-1
    do
      if paiGroup["My"][paiType][i] == prePai and paiGroup["My"][paiType][i+1] == prePai
      then
        local kezi = {paiGroup["My"][paiType][i],paiGroup["My"][paiType][i+1]}
        table.insert(attribute["Peng"],kezi)
      end
    end
  end

  -- 转换成对应userPai中的绝对位置
  table.sort( userPai, function (a,b) return a<b end )
  for i=1,#attribute["Peng"]
  do
    for k=1,#userPai
    do
      if attribute["Peng"][i][1] == userPai[k] and attribute["Peng"][i][2] == userPai[k+1]
      then
        attribute["Peng"][i][1] = k
        attribute["Peng"][i][2] = k+1
      end
    end
  end

  return attribute["Peng"]
end

--检测杠牌
--IN：用户牌，别人打的牌，是否自摸的标志（为加杠准备）
--OUT：所有可碰的牌的（！序号！）的table集合
--输出格式与吃牌类似
--注意：此处有加杠检测，需要拿碰牌组进行测试
function CheckGangPai(userPai,prePai,isNotZiMo)
  --杠牌
  local paiGroup = SortByType(userPai)

  local attribute = {["Gang"]={}}

  local paiType = CheckSinglePaiType(prePai)

  --明杠
  if #paiGroup["My"][paiType] and isNotZiMo == 1 then
    for i=1,#(paiGroup["My"][paiType])-2
    do
      if (paiGroup["My"][paiType][i] == prePai) and (paiGroup["My"][paiType][i+1] == prePai) and (paiGroup["My"][paiType][i+2] == prePai)
      then
        local gang = {paiGroup["My"][paiType][i],paiGroup["My"][paiType][i+1],paiGroup["My"][paiType][i+2]}
        table.insert(attribute["Gang"],gang)
      end
    end
  end

  --暗杠(自摸)
  if isNotZiMo == 0 then
    local all_pai = CopyPai(userPai)
    table.insert(all_pai,prePai)
    table.sort( all_pai )
    for i=1,#all_pai-2 do
      if CheckSinglePaiGroup(all_pai[i]) == Pai_My then
        if all_pai[i] == all_pai[i+1] and all_pai[i+1] == all_pai[i+2] and all_pai[i+2] == all_pai[i+3] then
          local gang = {all_pai[i],all_pai[i+1],all_pai[i+2]}
          table.insert(attribute["Gang"],gang)
        end
      end
    end
  end

  --加杠
  if #paiGroup["Peng"][paiType] and isNotZiMo == 0 then 
    prePai = GetPaiTypeNum(prePai)
    for i=1,#(paiGroup["Peng"][paiType]),3
    do
      if GetPaiTypeNum(paiGroup["Peng"][paiType][i]) == prePai and GetPaiTypeNum(paiGroup["Peng"][paiType][i+1]) == prePai and GetPaiTypeNum(paiGroup["Peng"][paiType][i+2]) == prePai
      then
        local gang = {GetPaiTypeNum(paiGroup["Peng"][paiType][i]),GetPaiTypeNum(paiGroup["Peng"][paiType][i+1]),GetPaiTypeNum(paiGroup["Peng"][paiType][i+2])}
        table.insert(attribute["Gang"],gang)
      end
    end
  end

  --转换成对应userPai中的绝对位置
  table.sort( userPai, function (a,b) return a<b end )
  for i=1,#attribute["Gang"]
  do
    for k=1,#userPai
    do
      if attribute["Gang"][i][1] == userPai[k] and attribute["Gang"][i][2] == userPai[k+1] and attribute["Gang"][i][3] == userPai[k+2]
      then
        attribute["Gang"][i][1] = k
        attribute["Gang"][i][2] = k+1
        attribute["Gang"][i][3] = k+2
      end
    end
  end

  return attribute["Gang"]
end

--广东麻将听牌，该函数功能未测试，实际项目中已去除听牌，但AI中会调用此方法作评测
--这一块可读性较差，如不启用听牌可以忽略
--IN：用户牌
--OUT：一个多重嵌套的table（不重复），每个基本单元是一个table，格式：{需要丢的牌，听的牌}
function CheckTingPai(userPai)
  local ting_list = {}
  local found_ting = false
  -- 分组
  local sort_pai = SortByType(userPai)
  --
  -- 检查听牌
  local pai_info = {
  [MJ_WAN]  = {false,0},
  [MJ_TIAO] = {false,0},
  [MJ_BING] = {false,0},
  [MJ_FENG] = {false,0},
  [MJ_ZFB]  = {false,0}}
  -- 统计各分组胡牌及将牌情况
  for i = 1,#sort_pai["My"] do
    pai_info[i][1],pai_info[i][2] = ValidHu(sort_pai["My"][i],1,#sort_pai["My"][i])
  end

  -- 统计 胡，将总数
  local sum_hu = 0
  local sum_jiang = 0
  for i = 1,5 do
    if pai_info[i][1] == true then
      sum_hu    = sum_hu    + 1
    end
    sum_jiang = sum_jiang + pai_info[i][2]
  end

  local collection = {
  [MJ_WAN]  = {11,12,13,14,15,16,17,18,19},
  [MJ_TIAO] = {21,22,23,24,25,26,27,28,29},
  [MJ_BING] = {31,32,33,34,35,36,37,38,39},
  [MJ_FENG] = {41,43,45,47},
  [MJ_ZFB]  = {51,53,55}}


  -- ********** 五组都“胡”，没法听 ****************************************************

  --************************************ 检查是否听 九莲宝灯 **********************************************************


  if sum_hu >= 3 and found_ting == false then
    -- 统计万条饼数目
    local num_count = {[MJ_WAN] = 0,[MJ_TIAO] = 0,[MJ_BING] = 0}
    for i = 1,#userPai do
      local paitype = CheckSinglePaiType(userPai[i])
      if paitype <= 3 then
        num_count[paitype] = num_count[paitype] + 1
      end
    end

    -- 检查是哪种牌 >=  13
    local pai_type = 0
    for i = 1,#num_count do
      if num_count[i] >= 13 then
        pai_type = i
      end
    end

    -- 相同牌数的牌 >= 13
    if pai_type ~= 0 then

      local count = {[1] = 0,[2] = 0,[3] = 0,[4] = 0,[5] = 0,[6] = 0,[7] = 0,[8] = 0,[9] = 0}
      for i = 1,#userPai do
        local m_type = CheckSinglePaiType(userPai[i])
        local m_num  = CheckSinglePaiNum(userPai[i])
        if m_type == pai_type then
          count[m_num] = count[m_num] + 1
        end
      end

      -- 统计缺少牌的情况
      local zero_count = 0
      local zero_num   = 0
      local size2_count= 0  -- 除111 和 999外，数目 >= 2 的组的数目
      local size2_num1  = 0  -- 该牌的索引
      local size2_num2 = 0
      for i = 1,#count do
        if count[i] == 0 then
          zero_count = zero_count + 1
          zero_num = i
        end
        if i ~= 1 and i ~= 9 then
          if count[i] >= 2 then
            size2_count = size2_count + 1
            if size2_num1 == 0 then
               size2_num1 = i
            else size2_num2 = i
            end
          end
        end
      end

      local target = 0
      local need   = 0
      if num_count[pai_type] == 13 then
        for i = 1,#userPai do
          if CheckSinglePaiType(userPai[i]) ~= pai_type then target = userPai[i] end
        end
      end

      ----------讨论13张同花色情况  -----
      if zero_count <= 1 and size2_count <= 1 and num_count[pai_type] == 13 then
        if  zero_count == 1 and count[1] >= 3 and count[9] >= 3 then
          found_ting  = true
          need        = zero_num + 10 * pai_type
        end
        if zero_num == 0 and count[1] == 2 and count[9] >= 3 then
          found_ting = true
          need       = 1 + 10 * pai_type
        end
        if zero_num == 0 and count[1] >= 3 and count[9] == 2 then
          found_ting = true
          need       = 9 * 10 * pai_type
        end

        if found_ting == true then
          local t_list = {target,need}
          table.insert(ting_list,t_list)
        end

        if zero_num == 0 and count[1] >= 3 and count[9] >= 3 then
          found_ting = true
          if count[1] ~= 4 then
            need = 1 + 10 * pai_type
            local t_list = {target,need}
            table.insert(ting_list,t_list)
          end
          if count[9] ~= 4 then
            need = 9 + 10 * pai_type
            local t_list = {target,need}
            table.insert(ting_list,t_list)
          end
        end
      end


      -------- 下面讨论14张同花牌的情况
      --　统计 2 ~ 8　的牌数和
      if num_count[pai_type] == 14 then
        local mid_count = 0
        for i = 2,8,1 do
          mid_count = mid_count + count[i]
        end
        -- 0  (2 8 4) or (4 2 8)
        if zero_count == 0 and mid_count == 8 and ( count[1] + count[9] == 6 ) and ( count[1] == 2 or count[1] == 4 ) then
           found_ting = true
           if count[1] == 2 then
            target = 9 + 10 * pai_type
            need   = 1 + 10 * pai_type
          else
            target = 1 + 10 * pai_type
            need   = 9 + 10 * pai_type
          end
          local t_list = {target,need}
          table.insert(ting_list,t_list)
        end
        -- 0  (2 9 3 ) or (3 9 2)
        if zero_count == 0 and mid_count == 9 and ( count[1] + count[9] == 5 ) and ( count[1] == 2 or count[1] == 3 ) then
          found_ting = true
          if count[1] == 2 then
            need   = 1 + 10 * pai_type
          else
            need   = 9 + 10 * pai_type
          end
          if size2_count == 1 then
            target = size2_num1 + 10 * pai_type
            local t_list = {target,need}
            table.insert(ting_list,t_list)
          elseif size2_count == 2 then
            local target1 = size2_num1 + 10 * pai_type
            local target2 = size2_num2 + 10 * pai_type
            local t_list1 = {target1,need}
            local t_list2 = {target2,need}
            table.insert(ting_list,t_list1)
            table.insert(ting_list,t_list2)
          end
        end
        -- 1 (3 7 4) or (4 7 3)
        if zero_count == 1 and mid_count == 7 and ( count[1] + count[9] == 7 ) and ( count[1] == 3 or count[1] == 4 ) then
          found_ting = true
          if count[1] == 4 then
               target1 = 1 + 10 * pai_type
          else target1 = 9 + 10 * pai_type end
          need = zero_num + 10 * pai_type
          local target2 = size2_num1 + 10 * pai_type
          local t_list1 = {target1,need}
          local t_list2 = {target2,need}
          table.insert(ting_list,t_list1)
          table.insert(ting_list,t_list2)

        end
        -- 1 (3 8 3)
        if zero_count == 1 and mid_count == 8 and ( count[1] == 3 and count[9] == 3 ) then
          found_ting = true
          need = zero_num + 10 * pai_type
          if size2_count == 1 then
          target = size2_num1 + 10 * pai_type
          local t_list = {target,need}
          table.insert(ting_list,t_list)
          elseif size2_count == 2 then
          local target1 = size2_num1 + 10 * pai_type
          local target2 = size2_num2 + 10 * pai_type
          local t_list1 = {target1,need}
          local t_list2 = {target2,need}
          table.insert(ting_list,t_list1)
          table.insert(ting_list,t_list2)
        end
      end
    end
  end
  -- if sum_hu == 5 then return false,0,0 end

  -- ********** 四组“胡”且将 == 0 或 1 ************************************************

  if sum_hu == 4 and sum_jiang < 2 and found_ting == false then
    -- 剩下的一组所需要的将 为 1 或 0
    local jiang_need = 1 - sum_jiang
    -- 找出是哪一组没法“胡”
    local target = 0
    for i = 1,#pai_info do
      if pai_info[i][1] == false then target = i end
    end

    -- 从该组第一张牌开始替换
    for i = 1,#sort_pai["My"][target] do
      local t_pai = sort_pai["My"][target][i]
      for j = 1,#collection[target] do
        -- local save_pai = sort_pai["My"][target][i]
        sort_pai["My"][target][i] = collection[target][j]
        local t = false
        local k = 0
        t,k = ValidHu(sort_pai["My"][target],1,#sort_pai["My"][target])
        -- 胡 且 达到所需将牌数目
        -- if t == true and k == jiang_need then return true,t_pai,collection[target][j] end
        if t == true and k == jiang_need then
          found_ting = true
          -- 注意本轮被替换的数实际是
          local t_list = {t_pai,collection[target][j]}
          table.insert(ting_list,t_list)
        end
      end
      sort_pai["My"][target][i] = t_pai
    end
  end

  -- ********** 三组“胡” 且将 == 0 或 1 ********************************************************
  if sum_hu == 3 and sum_jiang < 2 and found_ting == false then
    -- 找出是哪两组没法“胡”
    local target1 = 0
    local target2 = 0
    for i = 1,#pai_info do
      if pai_info[i][1] == false then
        if target1 == 0 then target1 = i
          else target2 = i
        end
      end
    end
    -- 剩下的两组所需要的将 为 1 或 0
    local jiang_need = 1 - sum_jiang
    -- 删掉第一组中的牌，往第二组加一张牌
    for i = 1,#sort_pai["My"][target1] do
      -- 记录下第一组牌中被删除的牌
      local t_pai = sort_pai["My"][target1][i]
      table.remove(sort_pai["My"][target1],i)
      local t1 = false
      local k1 = 0
      t1,k1 = ValidHu(sort_pai["My"][target1],1,#sort_pai["My"][target1])
      -- 删掉第一组牌能胡，给第二组牌添加一张牌，测试 胡 和将
      if t1 == true then
        for k = 1,#collection[target2] do
          local t_pai2 = CopyPai(sort_pai["My"][target2])
          table.insert(t_pai2,collection[target2][k])
          table.sort(t_pai2)
          local t2 = false
          local k2 = 0
          t2,k2 = ValidHu(t_pai2,1,#t_pai2)
          -- if t2 == true and k2 + k1 == jiang_need then return true,t_pai,collection[target2][k] end
          if t2 == true and k2 + k1 == jiang_need then
            found_ting = true
            local t_list = {t_pai,collection[target2][k]}
            table.insert(ting_list,t_list)
          end
        end
      end
      -- 还原第一组牌
      table.insert(sort_pai["My"][target1],i,t_pai)
    end
    -- 交换下位置
    -- 删掉第二组中的牌，往第一组加一张牌
    for i = 1,#sort_pai["My"][target2] do
      -- 记录下第二组牌中被删除的牌
      local t_pai = sort_pai["My"][target2][i]
      table.remove(sort_pai["My"][target2],i)
      local t1 = false
      local k1 = 0
      t1,k1 = ValidHu(sort_pai["My"][target2],1,#sort_pai["My"][target2])
      -- 第二组牌能胡，往第一组牌中加入牌，测试 胡、将
      if t1 == true then
      -- 往第一组牌加入一张牌
        for k = 1,#collection[target1] do
          local t_pai2 = CopyPai(sort_pai["My"][target1])
          table.insert(t_pai2,collection[target1][k])
          table.sort(t_pai2)
          local t2 = false
          local k2 = 0
          t2,k2 = ValidHu(t_pai2,1,#t_pai2)
          -- if t2 == true and k2 + k1 == jiang_need then return true,t_pai,collection[target1][k] end
          if t2 == true and k2 + k1 == jiang_need then
            found_ting = true
            local t_list = {t_pai,collection[target1][k]}
            table.insert(ting_list,t_list)
          end
        end
      end
      -- 还原第二组牌
      table.insert(sort_pai["My"][target2],i,t_pai)
    end
  end

  -- ************************************ 检查是否听 十三幺 **********************************************************
  if sum_hu < 3 and found_ting == false then
    local ssy_list = {11,19,21,29,31,39,41,43,45,47,51,53,55}
    local ssy_count = {
    [11] = 0,[19] = 0,[21] = 0,[29] = 0,[31] = 0,[39] = 0,[41] = 0,[43] = 0,[45] = 0,[47] = 0,[51] = 0,
    [53] = 0,[55] = 0}

    -- 扫描用户牌,统计出现十三幺各牌的个数
    for i = 1,#userPai do
      for j = 1,#ssy_list do
        if userPai[i] == ssy_list[j] then
          ssy_count[ssy_list[j]] = ssy_count[ssy_list[j]] + 1
        end
      end
    end

    local sum  = 0
    local zero = 0
    for i = 1,#ssy_list do
      if ssy_count[ssy_list[i]] == 0 then zero = zero + 1 end
      sum = sum + ssy_count[ssy_list[i]]
    end

    -- 能听的情况只有
    -- 1. zero = 0 &&  sum = 13   : 找出不在ssy_list 中的牌，返回 -- 11,19,21,29,31,39,41,43,45,47,51,53,55,()
    -- 2. zero = 1 &&  sum = 13   : 同 1                             11,(18),21,29,31,39,41,43,45,47,51,53,55,55
    -- 3. zero = 1 &&  sum = 14   : 找出牌数大于1的组，可能为两组或一组（3张相同）11,(11),21,29,31,39,41,43,45,47,51,53,55,55

    ---- 讨论 1,2 合为一种情况 -------------
    if ( zero == 0 or zero == 1 ) and sum == 13 then
      local target = 0
      for i = 1,#userPai do
        local found = false
        for j = 1,#ssy_list do
          if userPai[i] == ssy_list[j] then found = true end
        end
        if found == false then target = i end
      end
      -- 这里就只插入一张
      found_ting = true
      local t_list = {userPai[target],ssy_list[1]}
      table.insert(ting_list,t_list)
    end
    ---- 讨论3  ----------------------
    if zero ==  1 and sum ==  14 then
      -- 找出欠缺的牌
      local pai_need = 0
      for i = 1,#ssy_list do
        if ssy_count[ssy_list[i]] == 0 then pai_need = ssy_list[i] end
      end
      -- 找出牌数大于1的组,添加
      for i = 1,#ssy_list do
        if ssy_count[ssy_list[i]] > 1 then
          found_ting = true
          local t_list = {ssy_list[i],pai_need}
          table.insert(ting_list,t_list)
        end
      end
    end
  end
end
  -- 过滤掉相同的组
  local unique_list = {}
  for i = 1,#ting_list do
    local found_same = false
    for j = 1,#unique_list do
      if ting_list[i][1] == unique_list[j][1] and ting_list[i][2] == unique_list[j][2] then found_same = true end
    end
    if found_same ~= true then table.insert(unique_list,ting_list[i]) end
  end


  return unique_list
end

--递归检测刻子
--IN：用户手牌，检测起点，待检测牌总数
--OUT：是否全是刻子
local function CheckKe(userPai,i,n)
  -- 小于三张不可能刻
  if i > n then return true end
  if n - i < 2 then return false end
  if CheckAAAPai(userPai[i],userPai[i+1],userPai[i+2]) and CheckKe(userPai,i+3,n) then
    return true
  else
    return false end
end

--递归检测顺子
--IN：用户手牌，检测起点，待检测牌总数
--OUT：是否全是顺子
local function CheckShun(userPai,i,n)
  -- 小于三张不可能是顺子
  if i > n then return true end
  if n - i < 2 then return false end

  if CheckABCPai(userPai[i],userPai[i+1],userPai[i+2]) and CheckShun(userPai,i+3,n) then
    return true
  else
    return false end
end

-- 删除传进来的牌中的将牌
-- 仅用于删除 平胡或碰碰胡中的将牌 如 11 11 11 12 12 12 13 13 13 14 14 14 |(43 43)
-- 可能会删除 (11 11) 12 12 13 13 慎用
local function Deletejiang(userPai)
  local count = 0
  local last_pai = 0
  for i = 1,#userPai do
    local cur_pai = userPai[i]
    if cur_pai ~= last_pai then
      last_pai = cur_pai
      if count == 1 then
        table.remove(userPai,i-1)
        table.remove(userPai,i-2)
      end
      count = 0
    else
      count = count + 1
      last_pai = cur_pai
    end
  end

  -- 检测末尾部分
  if count == 1 then
    table.remove(userPai)
    table.remove(userPai)
  end
end

-- 检测平胡
local function CheckPH(userPai)
  -- 拷贝数组
  local t_pai = CopyPai(userPai)

  -- 删除将牌
  Deletejiang(t_pai)

  -- 保证只有一组将牌被删除,多组则返回
  if #t_pai ~= ( #userPai - 2 )  then return false end

  -- --检查剩下的牌是否只由顺子组成
  local sort_pai = SortByType(t_pai)
  for i = 1,#sort_pai["My"] do
    if #sort_pai["My"][i] ~= 0 then
      if CheckShun(sort_pai["My"][i],1,#sort_pai["My"][i]) == false then return false end
    end
  end

  return true
end

-- 检测碰碰胡
local function CheckPPH(userPai)
  -- 无顺子即可
  -- 拷贝数组
  local t_pai = CopyPai(userPai)

  -- 删除将牌
  Deletejiang(t_pai)

  -- 保证只有一组将牌被删除,多组则返回
  if #t_pai ~= ( #userPai - 2 ) then return false end

  local sort_pai = SortByType(t_pai)

  --检查剩下的牌是否只由刻组成
  for i = 1,#sort_pai["My"] do
    if #sort_pai["My"][i] ~= 0 then
      if CheckKe(sort_pai["My"][i],1,#sort_pai["My"][i]) == false then return false end
    end
  end

  return true

end

-- 检测混一色
local function CheckHYS(userPai)
  local sort_pai = SortByType(userPai)
  local count_wan  = #sort_pai["My"][MJ_WAN]
  local count_bing = #sort_pai["My"][MJ_BING]
  local count_tiao = #sort_pai["My"][MJ_TIAO]
  local count_feng = #sort_pai["My"][MJ_FENG]
  local count_zfb  = #sort_pai["My"][MJ_ZFB]
  -- 保证有字牌
  if count_feng == 0 and count_zfb == 0 then return false end
  -- 保证单花色
  if count_wan ~= 0 and count_tiao == 0 and count_bing == 0 then return true end
  if count_wan == 0 and count_tiao ~= 0 and count_bing == 0 then return true end
  if count_wan == 0 and count_tiao == 0 and count_bing ~= 0 then return true end

  return false
end

-- 检测混碰
local function CheckHP(userPai)  
  if CheckHYS(userPai) and CheckPPH(userPai) then return true end
  return false
end

--检测混幺九
local function CheckHYJ(userPai)
  -- 对 （万，饼，条 ）满足 幺九
  for i = 1,#userPai do
    local paitype = CheckSinglePaiType(userPai[i])
    local num     = CheckSinglePaiNum(userPai[i])

    if paitype == MJ_WAN or paitype == MJ_BING or paitype == MJ_TIAO then
      if num ~= 1 and num ~= 9  then
        return false
      end
    end
  end

  -- 检查是否有字牌，如果先检查 清幺九，则可以省去这步
  local found = false
  for i = 1,#userPai do
    if CheckSinglePaiType(userPai[i]) == MJ_FENG or CheckSinglePaiType(userPai[i]) == MJ_ZFB then
      found = true
    end
  end

  return found
end

-- 检测小三元
local function CheckXSY(userPai)
  local zhong = 0
  local fa    = 0
  local bai   = 0
  for i = 1,#userPai do
    local paitype = CheckSinglePaiType(userPai[i])
    if paitype == MJ_ZFB then
      if CheckSinglePaiNum(userPai[i]) == 1 then
        zhong = zhong + 1
      elseif CheckSinglePaiNum(userPai[i]) == 3 then
        fa    = fa  + 1
      elseif CheckSinglePaiNum(userPai[i]) == 5 then
        bai   = bai + 1
      end
    end
  end
  if zhong == 2 and fa >= 3 and bai >= 3 then return true end
  if zhong >= 3 and fa == 2 and bai >= 3 then return true end
  if zhong >= 3 and fa >= 3 and bai == 2 then return true end
  return false
end

-- 检测清一色
local function CheckQYS(userPai)
  local paitype = CheckSinglePaiType(userPai[1])
  if paitype == MJ_WAN or paitype == MJ_TIAO or paitype == MJ_BING then
    for i = 2,#userPai do
      local t = CheckSinglePaiType(userPai[i])
      if t ~= paitype then
        return false
      end
    end
  elseif paitype == MJ_FENG or paitype == MJ_ZFB then
    for i = 2,#userPai do
      if CheckSinglePaiType(userPai[i]) ~= MJ_FENG and CheckSinglePaiType(userPai[i]) ~= MJ_ZFB then
        return false
      end
    end
  end

  return true
end

-- 检测清碰
local function CheckQP(userPai)
  if CheckQYS(userPai) and CheckPPH(userPai) then return true end
  return false
end

-- 检测小四喜
local function CheckXSX(userPai)
  local dong = 0
  local nan  = 0
  local xi   = 0
  local bei  = 0
  for i = 1,#userPai do
    if CheckSinglePaiType(userPai[i]) == MJ_FENG then
      if CheckSinglePaiNum(userPai[i]) == 1 then
        dong = dong + 1
      elseif  CheckSinglePaiNum(userPai[i]) == 3 then
        nan  = nan + 1
      elseif CheckSinglePaiNum(userPai[i]) == 5 then
        xi   = xi  + 1
      elseif CheckSinglePaiNum(userPai[i]) == 7 then
        bei  = bei + 1
      end
    end
  end
  if dong == 2 and nan == 3 and xi == 3 and bei == 3 then return true end
  if dong == 3 and nan == 2 and xi == 3 and bei == 3 then return true end
  if dong == 3 and nan == 3 and xi == 2 and bei == 3 then return true end
  if dong == 3 and nan == 3 and xi == 3 and bei == 2 then return true end
  return false
end

-- 检测字一色
local function CheckZYS(userPai)
  for i = 1,#userPai do
    local paitype = CheckSinglePaiType(userPai[i])
    if paitype ~= MJ_ZFB and paitype ~= MJ_FENG then
      return false
    end
  end
  return true
end

-- 检测清幺九
local function CheckQYJ(userPai)
  for i = 1,#userPai do
    local paitype = CheckSinglePaiType(userPai[i])
    local num = CheckSinglePaiNum(userPai[i])
    -- 遇到字牌返回
    if paitype == MJ_FENG or paitype == MJ_ZFB then return false end
    -- 非字牌遇到非 1 9 ，返回
    if num ~= 1 and num ~= 9 then return false end
  end
  return true
end

-- 检测九莲宝灯
local function CheckJLBD(userPai)
  -- 穷举法
  -- 构造新列表 （ 使牌只有牌型和牌号)
  local t_pai = {}
  for i = 1,#userPai do
    table.insert(t_pai,GetPaiTypeNum(userPai[i]))
  end

  local JLBD_list = {
   {11,11,11,12,13,14,15,16,17,18,19,19,19},
   {11,11,11,11,12,13,14,15,16,17,18,19,19,19},{11,11,11,12,12,13,14,15,16,17,18,19,19,19},
   {11,11,11,12,13,13,14,15,16,17,18,19,19,19},{11,11,11,12,13,14,14,15,16,17,18,19,19,19},
   {11,11,11,12,13,14,15,15,16,17,18,19,19,19},{11,11,11,12,13,14,15,16,16,17,18,19,19,19},
   {11,11,11,12,13,14,15,16,17,17,18,19,19,19},{11,11,11,12,13,14,15,16,17,18,18,19,19,19},
   {11,11,11,12,13,14,15,16,17,18,19,19,19,19},{21,21,21,21,22,23,24,25,26,27,28,29,29,29},
   {21,21,21,22,22,23,24,25,26,27,28,29,29,29},{21,21,21,22,23,23,24,25,26,27,28,29,29,29},
   {21,21,21,22,23,24,24,25,26,27,28,29,29,29},{21,21,21,22,23,24,25,25,26,27,28,29,29,29},
   {21,21,21,22,23,24,25,26,26,27,28,29,29,29},{21,21,21,22,23,24,25,26,27,27,28,29,29,29},
   {21,21,21,22,23,24,25,26,27,28,28,29,29,29},{21,21,21,22,23,24,25,26,27,28,29,29,29,29},
   {31,31,31,31,32,33,34,35,36,37,38,39,39,39},{31,31,31,32,32,33,34,35,36,37,38,39,39,39},
   {31,31,31,32,33,33,34,35,36,37,38,39,39,39},{31,31,31,32,33,34,34,35,36,37,38,39,39,39},
   {31,31,31,32,33,34,35,35,36,37,38,39,39,39},{31,31,31,32,33,34,35,36,36,37,38,39,39,39},
   {31,31,31,32,33,34,35,36,37,37,38,39,39,39},{31,31,31,32,33,34,35,36,37,38,38,39,39,39},
   {31,31,31,32,33,34,35,36,37,38,39,39,39,39}}

   local found = false
   local n = #t_pai
   local count = 0
   for i = 1,#JLBD_list do
    for j = 1,#t_pai do
      if t_pai[j] == JLBD_list[i][j] then
        count = count + 1
      else
        count = 0 end
      if count == n then
        return true end
    end
   end
   return false
end

-- 检测大三元
local function CheckDSY(userPai)
  --从CheckHuScore传入的userPai包含自摸牌
  local zhong = 0
  local fa = 0
  local bai = 0
  for i=1,#userPai
  do
    if CheckSinglePaiType(userPai[i]) == MJ_ZFB then
      if CheckSinglePaiNum(userPai[i]) == 1 then
        zhong = zhong+1 
      end
      if CheckSinglePaiNum(userPai[i]) == 3 then
        fa = fa+1 
      end
      if CheckSinglePaiNum(userPai[i]) == 5 then
        bai = bai+1  
      end
    end
  end
  if zhong<3 or fa<3 or bai<3 then
    return false
  else
    return true end
end

--大四喜
local function CheckDSX(userPai)
  --从CheckHuScore传入的userPai包含自摸牌
  local dong = 0
  local nan = 0
  local xi = 0
  local bei = 0

  for i=1,#userPai do
    if CheckSinglePaiType(userPai[i]) == MJ_FENG then
      --东
      if CheckSinglePaiNum(userPai[i]) == 1 then
        dong = dong + 1 end
      --南
      if CheckSinglePaiNum(userPai[i]) == 3 then
        nan = nan + 1 end
      --西
      if CheckSinglePaiNum(userPai[i]) == 5 then
        xi = xi + 1 end
      --北
      if CheckSinglePaiNum(userPai[i]) == 7 then
        bei = bei + 1 end
    end
  end

  if dong < 3 or xi < 3 or nan < 3 or bei < 3 then
    return false
  else
    return true end
end

--十三幺
local function CheckSSY(userPai)
  -- （万筒索）1，9各一张， (东、南、西、北、中、发、白) 其中一个为两张，其余为一张
  --  典型  11 19 21 29 31 39 41 43 45 47 51 53 55 55

  local sort_pai = SortByType(userPai)
  -- 判断每组牌是否起码有2张
  -- if #sort_pai["My"][MJ_WAN] < 2 or #sort_pai["My"][MJ_TIAO] < 2 or #sort_pai["My"][MJ_BING] < 2 then return false end

  -- if CheckSinglePaiNum(sort_pai["My"][MJ_WAN][1])  ~= 1 or CheckSinglePaiNum(sort_pai["My"][MJ_WAN][2])   ~= 9 then return false end
  -- if CheckSinglePaiNum(sort_pai["My"][MJ_TIAO][1]) ~= 1 or CheckSinglePaiNum(sort_pai["My"][MJ_TIAO][2]) ~= 9 then return false end
  -- if CheckSinglePaiNum(sort_pai["My"][MJ_BING][1]) ~= 1 or CheckSinglePaiNum(sort_pai["My"][MJ_BING][2])  ~= 9 then return false end
  local wan1  = 0
  local wan9  = 0
  local tiao1 = 0
  local tiao9 = 0
  local bing1 = 0
  local bing9 = 0
  local dong  = 0
  local nan   = 0
  local xi    = 0
  local bei   = 0
  local zhong = 0
  local fa    = 0
  local bai   = 0

  -- 统计 1万、9万 个数
  for i = 1,#sort_pai["My"][MJ_WAN] do
    local pai = sort_pai["My"][MJ_WAN][i]
    local num = CheckSinglePaiNum(pai)
    if num == 1 then wan1 = wan1 + 1 end
    if num == 9 then wan9 = wan9 + 1 end
  end
   -- 统计 1条、9条 个数
  for i = 1,#sort_pai["My"][MJ_TIAO] do
    local pai = sort_pai["My"][MJ_TIAO][i]
    local num = CheckSinglePaiNum(pai)
    if num == 1 then tiao1 = tiao1 + 1 end
    if num == 9 then tiao9 = tiao9 + 1 end
  end

   -- 统计 1饼、9饼个数
  for i = 1,#sort_pai["My"][MJ_BING] do
    local pai = sort_pai["My"][MJ_BING][i]
    local num = CheckSinglePaiNum(pai)
    if num == 1 then bing1 = bing1 + 1 end
    if num == 9 then bing9 = bing9 + 1 end
  end

  -- 统计 ( 东南西北 )数目
  for i = 1,#sort_pai["My"][MJ_FENG] do
    local pai = sort_pai["My"][MJ_FENG][i]
    local num = CheckSinglePaiNum(pai)
    if num == 1 then dong = dong + 1 end
    if num == 3 then nan  = nan  + 1 end
    if num == 5 then xi   = xi   + 1 end
    if num == 7 then bei  = bei  + 1 end
  end
  --统计 ( 中发白 )数目
  for i = 1,#sort_pai["My"][MJ_ZFB] do
    local pai = sort_pai["My"][MJ_ZFB][i]
    local num = CheckSinglePaiNum(pai)
    if num == 1 then zhong = zhong + 1 end
    if num == 3 then fa    = fa    + 1 end
    if num == 5 then bai   = bai   + 1 end
  end

  -- 所有牌起码一个并且总和为 14
  local sum = wan1 + wan9 + tiao1 + tiao9 + bing1 + bing9 + dong + nan + xi + bei + zhong + fa + bai
  if wan1 > 0 and wan9 > 0 and tiao1 > 0 and tiao9 > 0 and bing1 > 0 and bing9 > 0 and dong > 0 and nan > 0 and xi > 0 and bei > 0 and
     zhong > 0 and fa  > 0 and bai > 0 and sum == 14 then return true end
  return false

end

--测试胡牌
--IN:用户牌
--OUT：true-胡，false-不能胡
function CheckHu(userPai)

  -- 先检测特殊牌型 (十三幺 和 九莲宝灯)
  if CheckSSY(userPai) or CheckJLBD(userPai) then return true end

  -- 检测普通胡牌牌型
  local sort_pai = SortByType(userPai)

  local count_hu    = 0
  local count_jiang = 0
  local t  = false        -- 临时变量
  local k  = 0            -- 临时变量
  -- 对各分组求"胡
  for i = 1,#sort_pai["My"] do
    t,k = ValidHu(sort_pai["My"][i],1,#sort_pai["My"][i])
    if t == true then count_hu    = count_hu + 1
      else break end
    count_jiang = count_jiang + k
  end

  if count_hu == 5 and count_jiang == 1 then
    return true
  else
    return false end
end

--打印牌组（debug用）
local function PrintPai(userPai)
  local sort_pai = SortByType(userPai)
  for i = 1,#sort_pai["My"] do
    for j = 1,#sort_pai["My"][i] do
     io.write(sort_pai["My"][i][j],",")
   end
    io.write("   ")
  end

end

--计算广东麻将胡牌番数
--此方法要求在已经胡牌的前提下调用
function CheckPaiXing(userPai)
  
  if CheckSSY(userPai)  == true then print("十三幺")  return 16 end
  if CheckJLBD(userPai) == true then print("九莲宝灯") return 15 end
  if CheckDSX(userPai)  == true then print("大四喜") return 14 end
  if CheckDSY(userPai)  == true then print("大三元") return 13 end
  if CheckQYJ(userPai)  == true then print("清幺九") return 12 end
  if CheckZYS(userPai)  == true then print("字一色") return 11 end
  if CheckXSX(userPai)  == true then print("小四喜") return 10 end
  if CheckXSY(userPai)  == true then print("小三元") return 9 end
  if CheckHYJ(userPai)  == true then print("混幺九") return 8 end
  if CheckQP(userPai)   == true then print("清碰") return 7 end
  if CheckHP(userPai)   == true then print("混碰") return 6 end
  if CheckQYS(userPai)  == true then print("清一色") return 5 end
  if CheckHYS(userPai)  == true then print("混一色") return 4 end
  if CheckPPH(userPai)  == true then print("碰碰胡") return 3 end
  if CheckPH(userPai)   == true then print("平胡") return 2 end
  print("鸡胡")
  return 1
end

--检查所有吃、碰、杠、听、胡（该方法为傻瓜式，服务端似乎已弃用，但客户端可能仍然在用）
--IN：用户牌，待检测牌，待检测牌来源标志
--flag参数指定第二个参数：0-自摸牌，1-上家牌，2-其他用户牌
--自摸牌不包含在userPai
function CheckAll(userPai,aPai,flag)
  
  --临时属性表(用于返回可操作牌型)
  local attribute = {
            ["Peng"] = {},--填每组能碰的牌，用表表示，以1开始，如第三第四张能碰，则填“{3,4}”
                    ["Chi"]  = {},--填每组能吃的牌，同上
                    ["Gang"] = {},--同上，填个三个数，如{7,8,9}
                    ["Ting"] = {},--填可以扔掉的牌，一位数，如{9}
                    ["Hu"]   = 0  --0表示不能胡，1表示能胡
            }

  --只有是上家牌才能吃
  if flag == 1
  then
    --吃
    attribute["Chi"] = CheckChiPai(userPai,aPai)
  end
  --不是自摸才能碰
  if flag ~= 0
  then
    --碰
    attribute["Peng"] = CheckPengPai(userPai,aPai)
  end

  --胡(自摸)
  local tempPai = CopyPai(userPai)
  table.insert(tempPai,aPai)
  if CheckHu(tempPai) == true then
    attribute["Hu"] = 1
  end

  --杠(判断胡牌后再判断自摸加杠)
  attribute["Gang"] = CheckGangPai(userPai,aPai,flag)
  return attribute
end

-- 检测三元牌
-- 中发白任意组成刻子，多少组加多少番
-- In：用户牌
-- Out：三元牌加番数
function CheckSYP( userPai )
  local paiarray = {}
  local count = 0
  for i=1,#userPai do
    table.insert(paiarray,userPai[i])
  end
  table.sort(paiarray)
  for i=1,#paiarray-2 do
    if GetPaiTypeNum(paiarray[i]) == GetPaiTypeNum(paiarray[i+1]) and 
      GetPaiTypeNum(paiarray[i]) == GetPaiTypeNum(paiarray[i+2]) and 
      CheckSinglePaiType(paiarray[i]) == MJ_ZFB then
      count = count + 1
    end
  end
  return count
end


--------------------------四川麻将专有胡法-----------------------------------

-------------带幺解法子操作开始-------------
--以下子操作仅限于检测四川麻将中的带幺九牌型
local function ValidABC_Split(pai,i,n,split_pai)
  -- 顺子要避开 1 222 3  这种可能组成 123 22 的情况
  -- 所以拆成两个列表  (1 2 3)|(22)
  -- 然后判断 ValidHu(22)

  local t_pai = CopyPai(pai)
  -- 只有两张牌，必定没顺
  if n - i < 2  then
    return false
  end

  local found_B = false
  local found_C = false
  for j = i+1,#t_pai,1 do
    if found_B == false and t_pai[j] == ( t_pai[i] + 1 ) then
      found_B = true
      -- 交换两张牌的位置
      local t = t_pai[i + 1]
      t_pai[i + 1] = t_pai[j]
      t_pai[j] = t
    end
  end

  for k = i + 2,#pai,1 do
    if found_C== false and t_pai[k] == ( t_pai[i] + 2 ) then
      found_C = true
      -- 交换两张牌的位置
      local t = t_pai[i + 2]
      t_pai[i + 2] = t_pai[k]
      t_pai[k] = t
    end
  end

  -- for k  = 1,#pai,1 do
  --  print (pai[k])
  -- end

  -- 如果能找到顺，判断剩下的牌是否能胡
  if found_B == true and found_C == true then
    --split_pai = {t_pai[i],t_pai[i+1],t_pai[i+2]}    --- 能组成顺子的列表
    table.insert(split_pai,t_pai[i])
    table.insert(split_pai,t_pai[i+1])
    table.insert(split_pai,t_pai[i+2])
    -- 创建待判断列表
    local new_list = {}
    local k = 1
    for j = i + 3,#pai,1 do
      new_list[k] = t_pai[j]
      k = k + 1
    end
    -- 对新建数组进行排序
    table.sort(new_list)
    -- for k = 1,#new_list,1 do
    --  print (new_list[k])
    -- end
    return true,new_list
  else
    return false,{nil}
  end
end

local function ValidHu_Split(pai,i,n,split_list,is_out) -- 最后一个参数表示是最外层
  -- 空牌组直接胡
  if n == 0 then
    return true,0
  end
  
  -- 存在两个将牌或少于两个牌，不可能胡
  if n%3==1 then 
    return false,0
  end

  -- 检测到末尾，胡
  if i > n then
    return true,0
  end

  -- 测试 AAA
  if ValidAAA(pai,i,n) then
    local merge_list = {}
    local t = false
    local k = 0
    t,k = ValidHu(pai,i+3,n,0)
    if t == true then
      local list = {}  
      --local list = {pai[i],pai[i],pai[i]}
      table.insert(list,pai[i])
      table.insert(list,pai[i])
      table.insert(list,pai[i])

      -- 如果是最外层，则将列表插入到新建的二级列表
      if is_out == true then
        table.insert(merge_list,list)
        ValidHu_Split(pai,i+3,n,merge_list,false)
      else
        -- 如果不是最外层，则将列表插入到传入的二级列表
        table.insert(split_list,list)
        return ValidHu_Split(pai,i+3,n,split_list,false)
      end

      -- 如果是最外层，则将列表的列表插入到三级列表
      if is_out  == true then
        table.insert(split_list,merge_list)
      end
    end
  end

  -- 测试AA
   if ValidAA(pai,i,n) then
    local merge_list = {}
    local t = false
    local k = 0
    t,k = ValidHu(pai,i+2,n)
    if t == true and k == 0 then       
     -- 限制 k == 0 可以解决 如 {11,11,11,12,12,12,13,13,13} 被拆分成
     -- {11,12,13}  {11,11} {12,12} {13,13} 的情况
      local list = {}
      table.insert(list,pai[i])
      table.insert(list,pai[i])
      -- 如果是最外层，则将列表插入到新建的二级列表
      if is_out == true then
        table.insert(merge_list,list)
        ValidHu_Split(pai,i+2,n,merge_list,false)
      else
        -- 如果不是最外层，则将列表插入到传入的二级列表
        table.insert(split_list,list)
        return ValidHu_Split(pai,i+2,n,split_list,false)
      end
      

      -- 如果是最外层，则将列表的列表插入三级列表
      if is_out  == true then
        table.insert(split_list,merge_list)
      end
    end
  end

  -- 对万，条，饼测试ABC
   if CheckSinglePaiType(pai[1]) ~= MJ_FENG and CheckSinglePaiType(pai[1]) ~= MJ_ZFB then
    local merge_list = {}
    local new_pai = {}
    local t       = false
    local list = {}
    t,new_pai = ValidABC_Split(pai,i,n,list)
    if t == true then
      local t2 = false
      local k  = 0
      t2,k = ValidHu(new_pai,1,#new_pai)
      if t2 == true then
        -- 如果是最外层，则将列表插入到新建的二级列表
        if is_out == true then
          table.insert(merge_list,list)
          ValidHu_Split(new_pai,1,#new_pai,merge_list,false)
        else
        -- 如果不是最外层，则将列表插入到传入的二级列表
          table.insert(split_list,list)
          return ValidHu_Split(new_pai,1,#new_pai,split_list,false)
        end
        
        -- 如果是最外层，则将列表的列表插入三级列表
        if is_out  == true then
          table.insert(split_list,merge_list)
        end
      end
    end
  end
  return false,0
end

local function SplitHuPai(userPai)
  -- 这个函数最初是为了解决四川麻将中的【带幺牌】设计的
  -- 接收 : 14张胡牌
  -- 返回 : 胡牌的组合
  ----  如接收   {11,11,11,12,12,12,13,13,13,51,51}
    ---- 返回   {
             -- {{11,11,11},{12,12,12},{13,13,13},{51,51}},
             -- {{11,12,13},{11,12,13},{11,12,13},{51,51}}
             -- }
  -- 分成四组牌
  local sort_pai = SortByType(userPai)

  local split_pai = {
  [MJ_WAN]  = {},
  [MJ_TIAO] = {},
  [MJ_BING] = {},
  [MJ_FENG] = {},
  [MJ_ZFB]  = {}
  }

  for i = 1,#sort_pai["My"] do
    ValidHu_Split(sort_pai["My"][i],1,#sort_pai["My"][i],split_pai[i],true) -- 最后一个参数表示是最外层
  end
  -- return split_pai
  local split_list = {}
  -- 下面的解法详见《编程之美》 ---- 3.2
  -- 各种子拆法的全组合
  -- 看起来比较恶心，实际上用递归更直观
  for i = 1,#split_pai do
    if #split_pai[i] ~= 0 then
      table.insert(split_list,split_pai[i])
    end
  end
  local  n = #split_list        -- 一共有n个非空组
  local  capacity = {}          -- 每个非空组的容量
  local  pos      = {}          -- 每个非空组当前的位置
  for i = 1,n do
    table.insert(capacity,#split_list[i])
    table.insert(pos,1)
  end

  local merge_list = {}
  while true do
    local t_list = {}
    for i = 1,#split_list do
      --table.insert(t_list,split_list[i][pos[i]])
      for j = 1,#split_list[i][pos[i]] do
        table.insert(t_list,split_list[i][pos[i]][j])
      end
    end
    table.insert(merge_list,t_list)
    local k = n
    while k >= 1 do
      if pos[k] < capacity[k] then
        pos[k] =pos[k] + 1
        break
      else
        pos[k] = 1
        k = k - 1
      end
    end
    if k < 1 then
      break
    end
  end
  return merge_list
end
-------------带幺解法子操作结束-------------

-- 检测缺门
local function CheckQueMen( userPai ,dingzhang )
  for i,v in ipairs(userPai) do
    if CheckSinglePaiType(v) == dingzhang  then
      return false
    end
  end

  return true
end

-- 平胡
-- 同广东麻将平胡，需缺门
local function CheckPh_SC( userPai )  
  if CheckPH(userPai) == true then
    return true
  else
    return false
  end
end

-- 大对子
-- 同广东麻将碰碰胡，需缺门
local function CheckDdz_SC( userPai )
  if CheckPPH(userPai) == true then
    return true
  else
    return false
  end
end

-- 清一色
-- 同广东麻将，自身满足缺门条件
local function CheckQys_SC( userPai )
  if CheckQYS(userPai) == true then
    return true
  else
    return false
  end
end

-- 带幺
-- 每组搭子及将牌都带1或9，需缺门
local function  CheckDy_SC( userPai )

  ----------------------优化---------------------------
  --如果牌中包含4~6的牌，不可能是带幺九，过滤之
  for i = 1,#userPai do
    local num = CheckSinglePaiNum(userPai[i])
    if num >= 4 and num <= 6 then return false end
  end
  ----------------------优化----------------------------

  local found = false          -- 能不能找到1或9
  local split_pai = SplitHuPai(userPai)

  for i = 1,#split_pai do    
    -- 扫描每一个胡牌组合
    for j = 1,#split_pai[i] do
      found = false
      -- 扫描每一种组合里面的牌对
      for k = 1,#split_pai[i][j] do
        local num = CheckSinglePaiNum(split_pai[i][j][k])
        if num == 1 or num == 9 then found = true end
      end
      -- 如果出现不含1，9的牌对，跳到上一层
      if found == false then break end
    end
    -- 如果扫完完整的一组时found == true 直接返回
    if found == true then return true end
  end

  return found
end


-- 暗七对
-- 七个对子，不遵循一般胡牌规律,需缺门
local function CheckAqd_SC( userPai )
  local sort_pai = {}
  for i=1,#userPai do
    if CheckSinglePaiGroup(userPai[i]) == Pai_My then
      table.insert(sort_pai,userPai[i])
    end
  end
  table.sort( sort_pai )

  if #sort_pai ~= 14 then
    return false
  end

  local isAQD = true
  for i=1,14 do
    if i % 2 == 1 then
      if sort_pai[i] ~=  sort_pai[i+1] then
        isAQD = false
        break
      end
    end
  end

  if isAQD == true then
    return true
  else
    return false
  end
end

-- 清大对
-- 即清一色+大对子
local function CheckQdd_SC( userPai )
  if CheckQys_SC(userPai) and CheckDdz_SC(userPai) then
    return true
  end
  return false
end

-- 龙七对
-- 暗七对的改进，七对中有两对或更多相同的牌，不能有杠
-- Out：bool 是否龙七对，number 相同的对数
local function CheckLqd_SC( userPai )
  if CheckAqd_SC(userPai) == false then
    return false,0
  end

  local num_gen = 0
  local sort_pai = {}
  --取手牌
  for i=1,#userPai do
    if CheckSinglePaiGroup(userPai[i]) == Pai_My then
      table.insert(sort_pai,userPai[i])
    end
  end
  table.sort( sort_pai )

  --双数位与单数位对比（相同则说明两对是相同的）
  for i=1,13 do
    if i%2 == 0 then
      if sort_pai[i] == sort_pai[i+1] then
        num_gen = num_gen + 1 
      end
    end
  end

  if num_gen ~= 0 then
    return true,num_gen
  else
    return false,0
  end
end

-- 清七对
-- 清一色+暗七对
local function CheckQqd_SC( userPai )
  if CheckQys_SC(userPai) and CheckAqd_SC(userPai) then
    return true
  end
  return false
end

-- 清龙七对
-- 清一色+龙七对
-- 返回值同龙七对
local function CheckQlqd_SC( userPai )
  local qys = CheckQys_SC(userPai);
  local lqd,num_gen = CheckLqd_SC(userPai)

  if qys and lqd then
    return true,num_gen
  else
    return false,0
  end
end

-- 清带幺
-- 清一色+带幺
local function CheckQdy_SC( userPai )
  if CheckQys_SC(userPai) and CheckDy_SC(userPai) then
    return true
  else
    return false
  end
end

-- 四川胡牌检测
-- 要检测定张,定张：1.万，2.条，3.饼
-- IN：用户牌，定张
-- OUT：是否胡牌
function CheckHu_SC( userPai,dingzhang )

  if CheckQueMen(userPai,dingzhang) == false then
    return false
  end

  --检测特殊牌型（七对系列）
  if CheckAqd_SC(userPai) == true then return true end

  -- 检测普通胡牌牌型
  local sort_pai = SortByType(userPai)

  local count_hu    = 0
  local count_jiang = 0
  local t  = false        -- 临时变量
  local k  = 0            -- 临时变量
  -- 对各分组求"胡
  for i = 1,#sort_pai["My"] do
    t,k = ValidHu(sort_pai["My"][i],1,#sort_pai["My"][i])
    if t == true then count_hu    = count_hu + 1
      else break end
    count_jiang = count_jiang + k
  end

  if count_hu == 5 and count_jiang == 1 then
    return true
  else
    return false end

end

-- 四川胡牌型的检测
-- 前提是能胡，此处不作判定
-- IN：用户牌
-- OUT：胡牌型编号
function  CheckPaiXing_SC( userPai )
  
  if CheckQlqd_SC(userPai) == true then print("清龙七对")  return 10 end
  if CheckQdy_SC(userPai)  == true then print("清带幺")    return 9 end
  if CheckQqd_SC(userPai)  == true then print("清七对")    return 8 end
  if CheckLqd_SC(userPai)  == true then print("龙七对")    return 7 end
  if CheckQdd_SC(userPai)  == true then print("清大对")    return 6 end
  if CheckAqd_SC(userPai)  == true then print("暗七对")    return 5 end
  if CheckDy_SC(userPai)   == true then print("带幺")      return 4 end
  if CheckQys_SC(userPai)  == true then print("清一色")    return 3 end
  if CheckDdz_SC(userPai)  == true then print("大对子")    return 2 end
  print("平胡")
  return 1
end

-- 四川麻将听牌（叫）
-- IN：用户牌，定张
-- OUT：听牌组（同广东麻将听牌结构）
function checkTingPai_SC( userPai , dingzhang )

  --暂时认为存在定张也能听（这里规则有待细化，需留意）
  local ting_list = {}
  local sort_pai = SortByType(userPai)

  local count_hu = 0  --表示万条饼中每一类可胡的总数
  local signal = 0  --表示未胡牌的牌种类，用作听牌检测
  local t = false
  local kj = 0
  for i=1,3 do
    --存在两张或以上的定张直接不能听
    if i == dingzhang and #sort_pai["My"][i] > 1 then
      return ting_list
    end 
    -- if i ~= dingzhang then 
      --只计算分组是否胡牌(包括定张)
      t,kj = ValidHu(sort_pai["My"][i],1,#sort_pai["My"][i]) 
      if t == true then
        count_hu = count_hu + 1
      else
        --记录下缺胡的牌种(不包括定张)
        if i~= dingzhang then
          signal = i
        end
      end
    -- end
  end

  --剩一门未胡，对其穷举
  if count_hu >= 1 then 
    --先看听定张
    if #sort_pai["My"][dingzhang] == 1 then
      for i=signal*10+1,signal*10+9 do
        --造一个新的table
        local list = {}
        list = CopyPai(sort_pai["My"][signal])
        table.insert(list,i)
        table.sort(list)

        t,kj = ValidHu(list,1,#list)
        if t == true then
          local oneTing = {sort_pai["My"][dingzhang][1],i}
          table.insert(ting_list,oneTing)
        end
      end
    end
    --从没有定张的手牌中穷举判断
    local shouPai = {}
    for i=1,#userPai do
      table.insert(shouPai,userPai[i])
    end
    for i=1,3 do
      for j=1,9 do
        local insertPai = i*10+j
        for k=1,#shouPai do
          local tempPai = {}
          for m=1,#shouPai do
            if m~=k then
              table.insert(tempPai,shouPai[m])
            end
          end
          table.insert(tempPai,insertPai)
          table.sort( tempPai )
          if CheckHu_SC(tempPai , dingzhang) then
            local oneTing = {shouPai[k],insertPai}
            table.insert(ting_list,oneTing)
          end
        end
      end
    end
  end

  --合并重复的听牌组
  --先排序
  local function sortTingList( a,b )
    if a[1] == b[1] then
      return a[2] < b[2]
    else
      return a[1] < b[1]
    end
  end
  table.sort( ting_list, sortTingList )
  --逆序删除
  for i = #ting_list,2,-1 do
    if ting_list[i][1] == ting_list[i-1][1] and
        ting_list[i][2] == ting_list[i-1][2] then
      table.remove(ting_list,i)
    end
  end

  return ting_list
end


-------------------------AI部分--------------------

-- 建立牌的权值
-- IN：用户牌
-- OUT：一个和用户牌一一对应的权值数组
local function createWeight(userPai)
  
  -- 根据手牌的权值决定出牌
  --这里不用剔除非手牌，因为非手牌的权值会很低
  local AIPai = CopyPai(userPai)
  table.sort( AIPai, function(a,b) return a<b end )
  --刻子
  local kezi = {}
  for i=1,#AIPai do
    table.insert(kezi,AIPai[i])
  end
  for i=1,#AIPai do
    if AIPai[i] == AIPai[i+1] and AIPai[i+1] == AIPai[i+2] then
      kezi[i],kezi[i+1],kezi[i+2] = -5,-5,-5
    end
  end
  --顺子
  local shunzi = {}
  for i=1,#AIPai do
    table.insert(shunzi,AIPai[i])
  end
  for i=1,#AIPai do
    for j=i,#AIPai do
      for k=j,#AIPai do
        if i~=j and j~=k and i~=k then
          if AIPai[i] == AIPai[j]-1 and AIPai[j] == AIPai[k]-1 then
            shunzi[i],shunzi[j],shunzi[k] = -4,-4,-4
          end
        end
      end
    end
  end
  --将牌
  local jiangpai = {}
  for i=1,#AIPai do
    table.insert(jiangpai,AIPai[i])
  end
  for i=1,#AIPai do
    for j=i,#AIPai do
      if i~=j then
        if AIPai[i] == AIPai[j] then
          jiangpai[i],jiangpai[j]= -3,-3
        end
      end
    end
  end
  --两张相邻或相隔一张（是否与顺子冲突）
  local lianzhang = {}
  for i=1,#AIPai do
    table.insert(lianzhang,AIPai[i])
  end
  for i=1,#AIPai do
    for j=i,#AIPai do
      if i~=j  and math.floor(AIPai[i]%100/10 ) == math.floor(AIPai[j]%100/10) then
        if (AIPai[i] == AIPai[j]-1 or AIPai[i] == AIPai[j]-2) and AIPai[i]%100/10<4 then
          if shunzi[i]<0 or shunzi[j]<0 then
            lianzhang[i],lianzhang[j]= -1,-1
          else
            lianzhang[i],lianzhang[j]= -2,-2
          end
        end
      end
    end
  end

  local weight = {}
  for i=1,#AIPai do
    table.insert(weight,AIPai[i])
    --修改为各种评价的总和而不是最小值，只取那些小于0的评价
    --以评判某些外部牌的影响
    local temp = 0
    if kezi[i] < 0 then
      temp = temp + kezi[i]
    end
    if shunzi[i] < 0 then
      temp = temp + shunzi[i]
    end
    if jiangpai[i] < 0 then
      temp = temp + jiangpai[i]
    end
    if lianzhang[i] < 0 then
      temp = temp + lianzhang[i]
    end
    if temp ~= 0 then
      weight[i] = temp
    end
  end

  return weight
end

-- 检测AI出牌
-- IN：用户牌，AI出牌等级
-- OUT：该出的牌（牌数值）
function checkAIChuPai(userPai,level)
  -- 加入听牌检测，能听就丢
  -- 加入AI等级，不同等级有不同的概率随便丢

  local AIPai = CopyPai(userPai)
  table.sort(AIPai)
  --剔除非手牌
  for i=#AIPai,1,-1 do
    if AIPai[i]>100 then 
      table.remove(AIPai,i)
    end
  end

  local rand = math.random(10)
  print("rand:"..rand)
  --随便丢，0级AI概率为0，1级为20%，2级为50%，3级为80%
  if rand < level*3 then
    return AIPai[math.random(#AIPai)]
  end

  local ting_list = CheckTingPai(AIPai)
  if #ting_list > 0 then
    return ting_list[1][1]
  end

  --返回出牌的序号
  local weight = createWeight(AIPai)
  local k = 1
  local typeNumGroup = {[MJ_WAN] = {},
                        [MJ_TIAO] = {},
                        [MJ_BING] = {},
                        [MJ_FENG] = {},
                        [MJ_ZFB] = {}
                      }
  for i=1,#weight do
    if weight[i] >0 then
      table.insert(typeNumGroup[CheckSinglePaiType(weight[i])],i)
    end
    if weight[k] < weight[i] then
      k=i
    end
  end
  --若存在正数（weight[k]>0），则选正数里最少的牌型出牌
  if weight[k]>0 and CheckSinglePaiType(weight[k]) < 4 then
    local min = CheckSinglePaiType(weight[k])
    for j=1,3 do
      if #typeNumGroup[j]>0 and (#typeNumGroup[j])<(#typeNumGroup[min]) then
        min = j
      end
    end
    --最少牌的牌组中选择最后一张丢出
    k = typeNumGroup[min][#typeNumGroup[min]]
  end
  return AIPai[k]
end

-- 检测AI是否吃碰杠
-- IN：用户牌，待检测的牌（注意：这里不作testPai来源判定，在外部逻辑已经有判断）
-- OUT：AItype(指示进行何种操作，0:忽略操作,1:吃,2:碰,3:杠),AIlist(可操作对应牌的值)
function checkAIAction(userPai,testPai)

  local AIPai = CopyPai(userPai)
  table.sort(AIPai)
  local AItype = 0
  local AIlist = {}

  local paitype = CheckSinglePaiType(testPai)
  local t_list = SortByType(AIPai)
  local t
  local k
  t,k = ValidHu(t_list["My"][paitype],1,#t_list["My"][paitype])
  if t == true then
    return AItype,AIlist 
  end

  local weight = createWeight(AIPai)
  local chi = CheckChiPai(AIPai,testPai)
  local peng = CheckPengPai(AIPai,testPai)
  local gang = CheckGangPai(AIPai,testPai,1)

  --为了综合评判整个手牌的状况，防止无脑的吃碰杠，设定吃碰杠的最小下界，必须大于此下界才会吃碰杠
  local gangline = -12  --杠下界
  local pengline = -7   --碰下界
  local chiline = -4    --吃下界

  --先杠
  if #gang>0 then
    local maxgroup = {gang[1][1],gang[1][2],gang[1][3]}
    if weight[maxgroup[1]] > gangline and weight[maxgroup[2]] > gangline and weight[maxgroup[3]] > gangline then
        table.insert(AIlist,AIPai[maxgroup[1]])
        table.insert(AIlist,AIPai[maxgroup[2]])
        table.insert(AIlist,AIPai[maxgroup[3]])
        AItype = 3
        return AItype,AIlist
    end
  end
  --再碰
  if #peng>0 then
    local maxgroup = {peng[1][1],peng[1][2]}
    if weight[maxgroup[1]] > pengline and weight[maxgroup[2]] > pengline then
        table.insert(AIlist,AIPai[maxgroup[1]])
        table.insert(AIlist,AIPai[maxgroup[2]])
        AItype = 2
        return AItype,AIlist
    end
  end
  --最后吃
  if #chi>0 then
    local maxgroup = {chi[1][1],chi[1][2]}
    for i=1,#chi do
      if weight[chi[i][1]]+weight[chi[i][2]] > weight[maxgroup[1]]+weight[maxgroup[2]] then
        maxgroup[1] = chi[i][1]
        maxgroup[2] = chi[i][2]
      end
    end
    if weight[maxgroup[1]] > pengline and weight[maxgroup[2]] > pengline then
        table.insert(AIlist,AIPai[maxgroup[1]])
        table.insert(AIlist,AIPai[maxgroup[2]])
        AItype = 1
        return AItype,AIlist
    end
  end
  return AItype,AIlist
end


---------------------------------- 测试  --------------------------------------------------------------------

-- local list = {
--     -- 删除将牌测试
-- {11,11,22,22,33,33,33,34,35,51,51,51,55,55},
-- {11,11,12,12,13,13,33,34,35,51,51,51,55,55},
-- --（十三幺） 所有可能
-- {11,19,21,29,31,39,39,41,43,45,47,51,53,55},
-- {11,19,21,29,31,39,41,41,43,45,47,51,53,55},
-- {11,19,21,29,31,39,41,43,43,45,47,51,53,55},
-- {11,19,21,29,31,39,41,43,45,45,47,51,53,55},
-- {11,19,21,29,31,39,41,43,45,47,47,51,53,55},
-- {11,19,21,29,31,39,41,43,45,47,51,51,53,55},
-- {11,19,21,29,31,39,41,43,45,47,51,53,53,55},
-- {11,19,21,29,31,39,41,43,45,47,51,53,55,55},
-- -- 十三幺 失败
-- {11,11,19,21,29,31,39,41,43,45,47,51,53,55},
-- {11,19,19,21,29,31,39,41,43,45,47,51,53,55},
-- {11,19,21,21,29,31,39,41,43,45,47,51,53,55},
-- {11,19,21,29,29,31,39,41,43,45,47,51,53,55},
-- {11,19,21,29,31,31,39,41,43,45,47,51,53,55},
-- {11,19,21,29,31,39,39,41,43,45,47,51,53,55},
-- -- （九莲宝灯） 所有可能
-- --{11,11,11,12,13,14,15,16,17,18,19,19,19}
-- {11,11,11,11,12,13,14,15,16,17,18,19,19,19},
-- {11,11,11,12,12,13,14,15,16,17,18,19,19,19},
-- {11,11,11,12,13,13,14,15,16,17,18,19,19,19},
-- {11,11,11,12,13,14,14,15,16,17,18,19,19,19},
-- {11,11,11,12,13,14,15,15,16,17,18,19,19,19},
-- {11,11,11,12,13,14,15,16,16,17,18,19,19,19},
-- {11,11,11,12,13,14,15,16,17,17,18,19,19,19},
-- {11,11,11,12,13,14,15,16,17,18,18,19,19,19},
-- {11,11,11,12,13,14,15,16,17,18,19,19,19,19},
-- -- 大四喜
-- {41,41,41,43,43,43,45,45,45,47,47,47,51,51},
-- {41,41,41,43,43,43,45,45,45,47,47,47,11,11},
-- -- 大三元
-- {51,51,51,53,53,53,55,55,55,11,11,11,12,12},
-- -- 清幺九
-- {11,11,11,19,19,19,21,21,21,29,29,29,31,31},
-- -- 字一色
-- {41,41,41,43,43,43,45,45,45,51,51,51,53,53},
-- {41,41,41,43,43,43,45,45,45,51,51,51,55,55},
-- -- 小四喜
-- {41,41,41,43,43,43,45,45,45,47,47,11,11,11},
-- {41,41,41,43,43,45,45,45,47,47,47,11,12,13},
-- {41,41,43,43,43,45,45,45,47,47,47,11,12,13},
-- -- 小三元
-- {51,51,51,53,53,53,55,55,11,11,11,12,12,12},
-- {51,51,53,53,53,55,55,55,41,41,41,43,43,43},
-- {51,51,51,53,53,55,55,55,22,23,24,25,26,27},
-- -- 混幺九
-- {11,11,11,19,19,19,21,21,21,29,29,29,51,51},
-- {11,11,11,19,19,19,21,21,21,29,29,29,53,53},
-- --清碰
-- {11,11,11,12,12,12,13,13,13,14,14,14,15,15},
-- {12,12,12,15,15,15,17,17,17,18,18,18,19,19},
-- -- 清一色
-- {11,11,11,12,13,14,15,15,15,16,17,18,19,19},
-- {11,11,11,11,12,13,14,15,16,17,17,17,18,18},
-- --  混碰
-- {11,11,11,12,12,12,13,13,13,14,14,14,51,51},
-- {11,11,11,12,12,12,13,13,13,14,14,14,53,53},
-- --  混一色
-- {11,11,11,12,12,12,13,13,13,51,51,53,53,53},
-- --  碰碰胡
-- {11,11,11,21,21,21,34,34,34,41,41,41,53,53},
-- --  平胡
-- {11,12,13,21,22,23,31,32,33,17,18,19,51,51},
-- --  鸡胡
-- {11,12,13,21,22,23,33,33,33,41,41,41,51,51},
-- {11,12,12,12,12,13,13,14,31,31,31,32,32,32},
-- --  四川麻将测试
-- {31,31,33,33,37,37,38,38,39,53,53,55,55,55},
-- {11,11,11,12,12,12,15,15,15,14,14,25,25,25},
-- {11,11,12,12,12,22,22,22,23,23,23,24,24,24},
-- {11,12,13,12,12,12,13,13,13,14,14,14,16,16},
-- {11,11,12,12,13,13,14,14,16,16,18,18,19,19},
-- {11,11,11,11,12,13,17,18,19,17,18,19,19,19},
-- {11,11,12,12,13,13,13,13}
-- }

--广东麻将吃牌测试
local ss = {11,214,214,214,13,15,23,23,25,26,26,26,31}
local sss = CheckGangPai(ss,14,0)
for i=1,#sss do
  for j=1,#sss[i] do
    print(sss[i][j])
  end
  print(" ")
end

-- 广东麻将胡牌测试
-- for i = 1,#list do
--   if CheckHu() == true then
--     CheckPaiXing(list[i])
--   else
--     print("no")
--   end
-- end

-- --四川麻将测试
-- for i = 1,#list do
--   if CheckHu_SC(list[i],MJ_BING) == true then
--     CheckPaiXing_SC(list[i])
--   else
--     print("no")
--   end
-- end

-- 测试三元牌
-- local syplist = {
--   {11,11,11,12,12,12,13,13,13,51,51,51,26,26},
--   {11,11,11,12,12,12,51,51,53,53,53,26,26,26},
--   {11,11,11,51,51,51,53,53,53,55,55,55,26,26},
--   {12,13,14,26,26,32,32,32,251,251,251,253,253,253}
-- }
-- for i=1,#syplist do
--   print(CheckSYP(syplist[i])) 
-- end

-- Debug用
-- temp = {11,11,13,15,16,16,22,23,24,24,25,26,34}
-- local atype,alist = checkAIAction(temp,12)
-- print(atype)
-- for i,v in ipairs(alist) do
--  print(i,v)
-- end

--10-28测试AI出牌
-- local aitest = {111,112,113,212,212,212,15,15,17,21,35}

-- print(checkAIChuPai(aitest));

-- local sc_list = {
--   {11,12,13,13,13,14,15,17,19,32,33,34,36,36},
--   {11,12,13,13,14,15,17,19,27,32,33,34,36,36},
--   {11,11,11,12,13,14,15,16,17,18,19,19,19,21},
--   {11,12,13,13,14,15,17,19,32,33,34,36,36,39},
--   {11,12,12,13,13,13,33,33}
-- }

-- for i=1,#sc_list do
--   local l = checkTingPai_SC(sc_list[i],MJ_TIAO)
--   --local l = CheckTingPai(sc_list[i])
--   for j=1,#l do
--     print(i)
--     io.write("丢：")
--     print(l[j][1])
--     io.write("听：")
--     print(l[j][2])
--   end
-- end

--1-23测试AI出牌
-- local testlist = {11,11,13,13,13,16,19}
-- aatype,resultlist = checkAIAction(testlist,13)
-- print(aatype)
-- for i=1,#resultlist do
--   print(resultlist[i])
-- end
-- print(checkAIChuPai(testlist,3))
-- print(checkAIChuPai(testlist,3))
-- print(checkAIChuPai(testlist,3))
-- print(checkAIChuPai(testlist,3))
-- print(checkAIChuPai(testlist,3))
-- print(checkAIChuPai(testlist,3))
-- print(checkAIChuPai(testlist,3))
-- print(checkAIChuPai(testlist,3))