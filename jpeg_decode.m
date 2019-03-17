function [output, cur_DC] = jpeg_decode(code, last_DC, lum_DC, lum_AC, quality)
index = 2;flag=0;
AC_len = length(lum_AC);
DC_len = length(lum_DC);
code_len = length(code);
count = 1;
while(~flag)
    start = code(1:index);
    if count == 1  %% 对DC译码
        found = 0;
        while(~found)
            for i = 1:DC_len
                if strcmp(start, lum_DC{i}) %% 查DC表
                    tri_tuple(count, 1) = 0;
                    tri_tuple(count, 2) = i - 1;
                    if  tri_tuple(count, 1) == 0 &&  tri_tuple(count, 2) == 0
                        tri_tuple(count, 3) = 0;
                         found = 1;
                         count = count + 1;
                         break;
                    end
                    len = class2len(i - 1);
                    start = code(index + 1:index+len);  %% 查找补码
                    index = index + len;
                    if start(1) == '0'
                        for j = 1:length(start)
                            if start(j) == '1'
                                start(j) = '0';
                            else
                                start(j) = '1';
                            end
                        end
                        tri_tuple(count, 3) = -bin2dec(start);
                    else
                        tri_tuple(count, 3) = bin2dec(start);
                    end
                    count = count + 1;
                    found = 1;
                    break;
                end
            end
            if found
                break;
            end
            index = index + 1;
            start = code(1:index);
        end
    else %% 对AC译码
        start = code(index+1:index + 2);
        s_index = index + 1;
        index = index + 2;
        
        found = 0;
        while(~found)
            for i = 1:AC_len
                if strcmp(start, lum_AC{i})
                    [tri_tuple(count, 1), tri_tuple(count, 2)] =  AC_index(i);%%查表结果
                    if tri_tuple(count, 1) == 0 && tri_tuple(count, 2) == 0   %%终止止符号
                        found = 1;
                        flag =1;
                        break;
                    else  
                        len = tri_tuple(count, 2);  %%补码长
                         if len >=1  %% 码长大于等于1
                            start = code(index + 1:index+len); 
                            index = index + len;
                            if start(1) == '0' 
                                for j = 1:length(start)
                                    if start(j) == '1'
                                        start(j) = '0';
                                    else
                                        start(j) = '1';
                                    end
                                end
                                tri_tuple(count, 3) = -bin2dec(start);
                            else
                                tri_tuple(count, 3) = bin2dec(start);
                            end
                         else   %% 码长为0
                                tri_tuple(count, 3) = 0;
                         end
                        count = count + 1;
                        found = 1;
                        break;
                    end
                end
            end
            if  found
                s_index = index + 1;
                if s_index + 1 >=code_len
                    flag = 1;
                    break;
                end
                index = s_index + 1;
                start = code(s_index:s_index + 1);
                found = 0;
            else
                index = index + 1;
                start = code(s_index:index);
            end
        end
    end
end

raw_vec = zeros(1,64);
index = 1;
for i = 1: size(tri_tuple,1)  %%恢复到原矩阵
    if i ==1 
        raw_vec(index) = tri_tuple(i, 3) + last_DC;
        index = index + 1;
    elseif (tri_tuple(i, 1) ~=0 || tri_tuple(i, 3) ~=0) && i ~= 1
      if tri_tuple(i, 1) ~= 0
          for j = 1:tri_tuple(i, 1)
              raw_vec(index) = 0;
              index = index + 1;
          end
          raw_vec(index) =  tri_tuple(i, 3);
          index = index + 1;
      else
          raw_vec(index) =  tri_tuple(i, 3);
          index = index + 1;
      end
    else
        raw_vec(index:64) = 0;
        break;
    end
end
cur_DC = raw_vec(1);
zigZagOrder = [0 1 5 6 14 15 27 28
    2 4 7 13 16 26 29 42
    3 8 12 17 25 30 41 43 
    9 11 18 24 31 40 44 53
    10 19 23 32 39 45 52 54
    20 22 33 38 46 51 55 60
    21 34 37 47 50 56 59 61
    35 36 48 49 57 58 62 63];

zigZagOrder = zigZagOrder +1;
mat_quant = zeros(8);

for i=1:8 %%恢复到原来的顺序
    for j=1:8
         mat_quant(i, j) = raw_vec(zigZagOrder(i, j));
    end
end

lumMat = [
    16 11 10 16 24 40 51 61;
    12 12 14 19 26 58 60 55;
    14 13 16 24 40 57 69 56;
    14 17 22 29 51 87 80 62;
    18 22 37 56 68 109 103 77;
    24 35 55 64 81 104 113 92;
    49 64 78 87 103 121 120 101;
    72 92 95 98 112 100 103 99];
if quality < 50
    quality = 50/quality;
else
    quality = 2 - quality/50;
end
lumMat = lumMat * quality;

 mat_dct =  mat_quant.*lumMat;
 output = round(idct2(mat_dct)) + 128;
% output = ceil(idct2(mat_dct));
end

function len = class2len(class)  %% 查DC表
    if class == 0
        len = 2;
    elseif ismember(class, [ 1, 2, 3, 4, 5])
        [~, index] = ismember(class, [ 1, 2, 3, 4, 5]);
        len = index;
    else
        [~, index] = ismember(class, [6, 7, 8, 9,10, 11]);
        len = index + 5;
    end
end

function [index1, index2] = AC_index(num) %% 查AC表
    if num <= 11 
        index1 = 0;
        index2 = num - 1;
    elseif num>151
        index1 = 15;
        index2 = num - 152;
    else
        index1 = floor(num/10);
        index2 = mod(num, 10) - 1;
    end
end
