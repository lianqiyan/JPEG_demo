clear;clc;
lum_AC = load_table('lum_AC.txt'); %%导入亮度直流霍夫曼编码表 
lum_DC = load_table('lum_DC.txt'); %%亮度交流霍夫曼编码表
global DC_len; 
global AC_len;
[DC_len, AC_len] = get_code_len(lum_AC, lum_DC);


CELL_SIZE = 8;
img = imread('lena.bmp');
img = double(img);
img = img - 128;
repeat_height = size(img, 1)/CELL_SIZE;
repeat_width = size(img, 2)/CELL_SIZE;
repeat_height_mat = repmat(CELL_SIZE, [1 repeat_height]);
repeat_width_mat = repmat(CELL_SIZE, [1 repeat_width]);
sub_image = mat2cell(img, repeat_width_mat, repeat_height_mat);
img = img + 128;
num_bits = size(img, 1) * size(img, 2) * 8;


en_last_DC = 0;
de_last_DC = 0;
zero_count = 0;
decode_img = zeros(512);
de_sub_image = mat2cell(decode_img, repeat_width_mat, repeat_height_mat);
all_str = '';

tic
for i=1:repeat_height
    for j=1:repeat_width
        [res, en_last_DC] = encode(sub_image{i, j}, en_last_DC, lum_DC, lum_AC); %%编码 quality设置为 60
        all_str = strcat(all_str, res);
    end
end
toc

cod_eff = compute_efficiency(AC_len, DC_len);

%写入文件
path = 'JPEGCODE.txt'; 
fid = fopen(path,'w');
fprintf(fid,'%s',all_str);
fclose(fid);

de_img = cell2mat(de_sub_image);
disp([' 编码长为'])
disp(length(all_str))
disp([' 压缩比为'])
disp(num_bits/length(all_str))
disp([' 压缩效率为'])
disp(cod_eff)

toc


function [DC_len, AC_len] = get_code_len(AC, DC)
    AC_len = zeros(length(AC), 2);
    DC_len = zeros(length(DC), 2);
    for i = 1: length(AC)
        AC_len(i, 1) = length(AC{i});
    end
    for i = 1: length(DC)
        DC_len(i, 1) = length(DC{i});
    end
end

function code = load_table(file_name)
    index = 1;
    fid = fopen(file_name);
    tline = fgetl(fid);
    while ischar(tline)
        code{index} = tline;
        tline = fgetl(fid);
        index = index + 1;
    end
    fclose(fid);
end

function comp_efficiency = compute_efficiency(AC, DC)
    p_code = [AC(:,2)./sum(AC(:, 2)); DC(:, 2)./sum(DC(:, 2))];
    temp = -p_code.*log2(p_code);
    temp(isnan(temp)) = 0;
    H = sum(temp);
    code_len = [AC(:,1); DC(:, 1)];
    L = sum(p_code.*code_len);
    comp_efficiency = H/L;
end
