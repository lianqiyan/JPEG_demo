function [output, cur_DC] = jpeg_encode(input, last_DC, lum_DC, lum_AC, quality)
global DC_len; 
global AC_len;
mat_dct = round(dct2(input));
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

mat_quant = round(mat_dct./lumMat);

%%% 取当前DC系数, 并减去上一个DC系数
cur_DC = mat_quant(1,1);
mat_quant(1,1) = mat_quant(1,1) - last_DC;
zigZagOrder = [0 1 5 6 14 15 27 28
    2 4 7 13 16 26 29 42
    3 8 12 17 25 30 41 43 
    9 11 18 24 31 40 44 53
    10 19 23 32 39 45 52 54
    20 22 33 38 46 51 55 60
    21 34 37 47 50 56 59 61
    35 36 48 49 57 58 62 63];
zigZagOrder = zigZagOrder +1;
mat_quant_zig = zeros(1, 64);

for i=1:8
    for j=1:8
        mat_quant_zig(zigZagOrder(i, j)) = mat_quant(i, j);
    end
end

% mat_quant_zig(1) = mat_quant_zig(1) - 20;
%%% 构造二元组
last_index = 2;
for i = length(mat_quant_zig):-1:1
    if mat_quant_zig(i) ~= 0
        last_index = i;
        break;
    end
end

index = 1;
t_cnt = 1;
if mat_quant_zig(1) == 0
    t_tuple(t_cnt, :) = [1, 0];
    t_cnt = t_cnt + 1;
    index = index + 1;
end
while(index<64)
    count = 0;
    while( mat_quant_zig(index) == 0)
        count = count + 1;
        index = index + 1;
        if count == 16 || index > last_index
            break;
        end
    end
    if index <=last_index && count <= 16 && mat_quant_zig(index)
        if count == 16 && mat_quant_zig(index-1) == 0
            t_tuple(t_cnt, :) = [count-1,0];
            index = index - 1;
        else
             t_tuple(t_cnt, :) = [count, mat_quant_zig(index)];
        end
    elseif index > last_index
        t_tuple(t_cnt, :) = [0,0];
        break;
    end
    t_cnt = t_cnt + 1;
    index = index + 1;
end

%%% 构造三元组
tri_tuple = zeros(size(t_tuple, 1), 3);
for i = 1:size(t_tuple, 1)
    if i == 1
        tri_tuple(i, 2) = DC_AC_class(t_tuple(i, 2));
        tri_tuple(i, 1) = 0;
        tri_tuple(i, 3) = t_tuple(i, 2);
    else
        tri_tuple(i, 1) = t_tuple(i, 1);
        tri_tuple(i, 2) = DC_AC_class(t_tuple(i, 2));
        tri_tuple(i, 3) = t_tuple(i, 2);
    end  
end


%%% 查找哈夫曼表
len = size(tri_tuple, 1);
encode = cell(len, 2);
for i = 1:len
    if i == 1
        encode{i, 1} = lum_DC{tri_tuple(i, 2) + 1};
        DC_len(tri_tuple(i, 2) + 1, 2) =  DC_len(tri_tuple(i, 2) + 1, 2) + 1;
        encode{i, 2} = complement(tri_tuple(i,3));
    elseif i ==len
        encode{i, 1} = '1010';
        AC_len(1, 2) = AC_len(1, 2) + 1;
        encode{i, 2} = '';
    else
        encode{i, 1} = AC_code(tri_tuple(i, 1), tri_tuple(i, 2), lum_AC);
        encode{i, 2} = complement(tri_tuple(i,3));
    end
end

output = '';
for i = 1:size(encode, 1)
    output = strcat(output, encode{i, 1}, encode{i, 2});
end
end


function out = complement(in)
    if in > 0
        out = num2str(dec2bin(in));
    elseif in == 0
        out = '';
    elseif in == -1
        out = '0';
    else
        out =  num2str(dec2bin(-in));
        for i = 1:length(out)
            if out(i) == '1'
                out(i) = '0';
            else
                out(i) = '1';
            end
        end
    end
end

function out = AC_code(code1, code2, table)
    global AC_len
    if code1 == 0
        index = code2 + 1;
    elseif code1 == 15
        index = 10 * 15 + code2 + 2;
    else
        index = 10 * (code1) + code2 + 1;
    end
    AC_len(index, 2) = AC_len(index, 2) + 1;
    out = table{index};
end   

function class = DC_AC_class(num) 
    if num == 0
        class = 0;
    elseif (num == -1) || (num==1)
        class = 1;
    elseif (num == -3) || ( num == -2) || (num == 2) || (num == 3)
        class = 2;
    elseif (num <=-4 && num >= -7) ||  (num <=7  && num >= 4)
        class = 3;
    elseif (num <=-8 && num >= -15) ||  (num <=15  && num >= 8)
        class = 4;
    elseif (num <=-16 && num >= -31) ||  (num <=31  && num >= 16)
        class = 5;
    elseif (num <=-32 && num >= -63) ||  (num <=63   && num >= 32)
        class = 6;
    elseif (num <=-64 && num >= -127) ||  (num <= 127  && num >= 64)
        class = 7;
    elseif (num <=-128 && num >= -255) ||  (num <=255  && num >= 128)
        class = 8;
    elseif (num <=-256 && num >= -511) ||  (num <=511  && num >= 256)
        class = 9;
    elseif (num <=-512 && num >= -1023) ||  (num <=1023  && num >= 512)
        class = 10;
    elseif (num <=-1024 && num >= -2047) ||  (num <=2047  && num >= 1024)
        class = 11;
    else
        disp('other value')
    end
end
