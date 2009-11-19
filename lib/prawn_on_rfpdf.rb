class PrawnOnRFPDF

  def self.generate(filename, options ={}, &block)
    pdf = self.new(options)
    block.call(pdf)
    pdf.save(filename)
  end

  def bounding_box( position, options = {}, &block)
    x = position[0]
    y = position[1]
    #width = options[:width]
    #height = options[:height]

    @relative = [x,y]
    block.call(self)
    @relative = [0,0]
  end

  def start_new_page
    @pdf.AddPage
  end

  # http://chensh.loxa.edu.tw/php/X_1.php
  def fix_big5_binary(org_str)

    tmp_length = org_str.length

    (0...tmp_length).to_a.each do |tmp_i|

      ascii_str_a = org_str[tmp_i,1]
      ascii_str_b = org_str[tmp_i+1, 1]
      ascii_str_c = org_str[tmp_i-1, 1] if tmp_i > 0

      ascii_value_a = ascii_str_a.ord if ascii_str_a
      ascii_value_b = ascii_str_b.ord if ascii_str_b
      ascii_value_c = ascii_str_c.ord if ascii_str_c

      if ( ascii_value_a && ascii_value_a >= 129 && ascii_value_a <= 254 ) &&
        ascii_value_b && (
          ( ascii_value_b >= 64 && ascii_value_b <= 126 ) || ( ascii_value_b >= 161 && ascii_value_b <= 254 )
      )

      # this is valid big5 character first byte
      #puts "1: #{ascii_value_a}"

      if ( ascii_value_b == 92 )
        #puts "ascii_value_b==92"
        org_str.insert( tmp_i+2 ,"\\" )
        #puts @icutf8.iconv( org_str )
        tmp_length = org_str.length
      end

      elsif ( ascii_value_c && ascii_value_c >= 129 && ascii_value_c <= 254 ) &&
        ascii_value_a && (
          ( ascii_value_a >= 64 && ascii_value_a <= 126 ) || ( ascii_value_a >= 161 && ascii_value_a <= 254 )
      )
      # this is valid big5 characer second byte
      #puts "2: #{ascii_value_a}"
      elsif ascii_value_a && ascii_value_a >= 32 && ascii_value_a <= 126
        # this is valid print-able ascii
        #puts "3: #{ascii_value_a}"
      else
        # this is invalid byte
        #puts "4: invalid #{ascii_value_a}"
        org_str[tmp_i,1] = "?"
      end
    end

    tmp_length = org_str.length
    if ( org_str[tmp_length-1, 1] == "\\" )
      org_str.concat(" ")
    end

    return org_str

  end

  def safe_big5_iconv(s)
    return "" if s.blank?
    s.strip!

    s.gsub!("\\","\\\\\\\\")
    s.gsub!("【", "[")
    s.gsub!("】", "]")
    s.gsub!("（","(")
    s.gsub!("）",")")

    s = @icBig5.iconv(s) rescue s.split("").map { |c| @icBig5.iconv(c) rescue '?' }.join("")
    s = fix_big5_binary(s)

    return s
  end

  def text(text, options={})
    return if text.blank?

    x = options[:at][0]
    y = options[:at][1]
    font_size = options[:size] || 8
    w = options[:width]
    h = options[:height] || 3
    align = options[:align] || "L"
    disable_auto_line_break = options[:disable_auto_line_break] || false

    @pdf.SetFont('Big5','', font_size)

    if !w && align == "L"
      text = safe_big5_iconv(text.to_s)
      @pdf.SetXY( x + @relative[0], y + @relative[1])
      @pdf.Write(0, text.to_s )
    else
      big5_string_array = split_to_array(text.to_s, w)

      big5_string_array.each_with_index do |str, i|
        @pdf.SetXY( x + @relative[0], y + @relative[1] + i*h ) # break line happened
        if w && align == "R"
          # FIXME: multi line align R text has bug
          @pdf.MultiCell(w, 0, str, 0, "R")
        else
          @pdf.Write(0, str)
        end
        break if disable_auto_line_break
      end

    end

  end

  def barcode(text, options={})
    return if text.blank?

    # http://www.code39barcodes.com/Code-39-character-set.html
    text.gsub!(/[^a-zA-Z0-9\-.$\/+%* ]/,"")

    x = options[:at][0]
    y = options[:at][1]
    font_size = options[:size] || 11

    @pdf.SetFont( RAILS_ROOT+"/vendor/plugins/rfpdf/lib/fpdf/3of9",'', font_size)
    @pdf.SetXY( x + @relative[0], y + @relative[1])

    @pdf.Write(0, "*#{text}*")

  end

  def image(file, options={})
    x = (options[:at])? options[:at][0] : 0
    y = (options[:at])? options[:at][1] : 0
    w = options[:width] || 0
    h = options[:height] || 0

    @pdf.Image( file, x,y, w,h )
  end

  def background(file, options={})
    options[:at] ||= [0,0]
    image(file, :at => options[:at], :width => @paper_width, :height => @paper_height)
  end

  def rectangle(x1,y1,x2,y2)
    self.line(x1, y1, x2, y1) #top
    self.line(x1, y2, x2, y2) #bottom
    self.line(x1, y1, x1, y2) #left
    self.line(x2, y1, x2, y2) #right
  end

  def line(x1,y1,x2,y2)
    @pdf.draw_line( x1, y1, x2, y2, :line_width => 0.2)
  end

  def initialize(options={})

    # A4
    @paper_width = options[:width] || 210
    @paper_height = options[:height] ||= 297

    k = 72/25.4
    width =@paper_width * k
    height = @paper_height * k

    @pdf = FPDF.new("P",'mm',[@paper_width, @paper_height])
    @pdf.extend(PDF_Chinese)
    @pdf.AddPage

    @pdf.AddBig5Font
    @pdf.AddFont( RAILS_ROOT+"/vendor/plugins/rfpdf/lib/fpdf/3of9",'')

    @pdf.SetFont('Big5','',options[:font_size] || 12)

    @pdf.SetAutoPageBreak(false, 0)
    @pdf.SetDisplayMode('real')

    @pdf.SetTopMargin(0)
    @pdf.SetLeftMargin(0)
    @pdf.SetRightMargin(0)

    @icBig5 = Iconv.new('Big5', 'UTF-8')
    @icASCII = Iconv.new('ASCII//IGNORE', 'UTF-8')

    @relative = [0,0]
  end

  def save(filename)
    @pdf.Output(filename)
  end

  def table(data, options = {})
    data = cutdown_data_string(data)

    x = options[:at][0] + @relative[0]
    y = options[:at][1] + @relative[1]
    font_size = options[:size] || 8
    headers = options[:headers]

    @pdf.SetXY(x,y)
    @pdf.SetFont('Big5','', font_size)

    table_width = @paper_width - 2*x
    col_width_arr = (options[:col_width_arr]) ? options[:col_width_arr] : calculate_table_column_width(table_width, data, options)

    default_row_height = (font_size / 2)
    total_rows_count = 0

    if headers
      headers.each_with_index do |th, col_index|
        @pdf.SetXY( x + col_width_arr.first(col_index).sum, y )
        text = safe_big5_iconv( th )
        if options[:align_right] && options[:align_right].include?(col_index)
          @pdf.MultiCell(col_width_arr[col_index] , 0, text.to_s, 0, "R")
        else
          @pdf.Write(0, text.to_s )
        end
      end
      total_rows_count += 1
      y += default_row_height
      self.line(x, y - default_row_height/2, x+table_width, y - default_row_height/2)
    end

    extra_rows_count = 0 # "extra" means we need more height when break line happened
    data.each_with_index do |row_data, row_index|
      extra_rows_count_candidate = [] # we will choose a max extra_rows_count every row
      total_rows_count += 1

      row_data.each_with_index do |col_data, col_index|
        extra_rows_count_in_this_col = -1

        big5_string_array = split_to_array( col_data, col_width_arr[col_index] )

        big5_string_array.each_with_index do |text, i|
          extra_rows_count_in_this_col += 1
          @pdf.SetXY( x + col_width_arr.first(col_index).sum, y + default_row_height*(row_index+extra_rows_count+extra_rows_count_in_this_col ) ) # break line happened

          if options[:align_right] && options[:align_right].include?(col_index)
            @pdf.MultiCell(col_width_arr[col_index] , 0, text.to_s, 0, "R")
          else
            @pdf.Write(0, text.to_s)
          end

        end

        extra_rows_count_candidate << extra_rows_count_in_this_col
      end

      max_extra_rows_count_in_this_row = extra_rows_count_candidate.max

      extra_rows_count = extra_rows_count + max_extra_rows_count_in_this_row
      total_rows_count += max_extra_rows_count_in_this_row
    end

    if options[:footer_line]
      line_y = y + ( total_rows_count.to_f - 2.5 ) * default_row_height
      self.line(x, line_y, x+table_width, line_y)
    end

    return total_rows_count
  end

  def calculate_table_pages(data, options = {})
    return [] if data.empty?

    x = options[:at][0] + @relative[0]
    y = options[:at][1] + @relative[1]
    table_width = @paper_width - 2*x

    data = cutdown_data_string(data)

    col_width_arr = calculate_table_column_width(table_width, data, options)
    options.merge!( :col_width_arr => col_width_arr)

    how_many_data_in_this_page = []
    total_data = data.size
    remain_data = data.clone

    loop do
      remain_data_size = remain_data.size
      remain_data = self.pre_process_table_rows(remain_data, options)
      break unless remain_data
      how_many_data_in_this_page << ( remain_data_size - remain_data.size )
    end

    how_many_data_in_this_page << total_data - how_many_data_in_this_page.sum # last page

    return how_many_data_in_this_page, col_width_arr
  end

  def split_to_array(text, width)
    arr = []
    loop do
      restrict_big5_text, text = calculate_string(text, width - 3) # for table padding
      arr << restrict_big5_text
      break unless text
    end

    return arr
  end

  protected

  def calculate_string(text, width)
    big5_text = safe_big5_iconv( text.to_s )
    big5_text_width = @pdf.GetStringWidth(big5_text)

    if big5_text_width > width
      reserve_percent = width / big5_text_width
      text_size = text.mb_chars.size

      restrict_size = (text_size*reserve_percent).floor.to_i

      restrict_big5_text = safe_big5_iconv( text.mb_chars[0, restrict_size] )
      while @pdf.GetStringWidth(restrict_big5_text) > width
        restrict_size = restrict_size - 1
        restrict_big5_text = safe_big5_iconv( text.mb_chars[0, restrict_size] )
      end

      remained_text = (text && text.mb_chars.size > 0 )? text.mb_chars[restrict_size, text.mb_chars.size - restrict_size ] : nil

      return restrict_big5_text, remained_text
    else

      return big5_text, nil
    end
  end

  def cutdown_data_string(data, max_chars=100)
    return data.map do |d|
      d.map do |s|
        if s.to_s.mb_chars.size > max_chars
          s = "#{s.to_s.chars[0,max_chars].to_s} ＃＃＃"
        else
          s
        end
      end
    end
  end

  def calculate_table_column_width(table_width, data, options = {})
    col_size = data[0].size
    col_width_arr = Array.new(col_size)

    # assign column width if we specify it, and calculate default column width.
    if options[:col_width] && ( col_size - options[:col_width].size ) != 0
      specify_width = options[:col_width].map{ |c| c[1] }.sum
      specify_col_size = options[:col_width].size

      default_col_width = ( table_width.to_f - specify_width ) / ( col_size - specify_col_size )

      options[:col_width].each do |cw|
        col_width_arr[ cw[0] ] = cw[1]
      end
    else
      specify_width = 0
      specify_col_size = 0
      default_col_width = table_width.to_f / col_size
    end

    # find max width every column
    col_max_width = []

    if options[:headers]
      options[:headers].each_with_index do |th, col_index|
        text = safe_big5_iconv( th )
        col_max_width[col_index] = @pdf.GetStringWidth(text)
      end
    end

    data.each_with_index do |row_data, row_index|
      row_data.each_with_index do |col_data, col_index|
        text = safe_big5_iconv( col_data.to_s )
        text_width = @pdf.GetStringWidth(text)
        col_max_width[col_index] = text_width if ( text_width > col_max_width[col_index] )
      end
    end

    # assign column width if it need not so much space, and given 4 is a padding width
    more_width = 0
    col_max_width.each_with_index do |width, index|
      if options[:col_width]
        next if options[:col_width].map{ |c| c[0] }.include?(index)
      end

      if ( width + 4 < default_col_width )
        col_width_arr[index] = width + 4 # new width
        specify_col_size += 1
        more_width += ( default_col_width - width - 4 )
      end
    end

    # re-calculate default column width
    default_col_width = default_col_width + ( more_width / ( col_size - specify_col_size ) )

    col_width_arr.each_with_index do |w, i|
      col_width_arr[i] = default_col_width unless w
    end

    return col_width_arr
  end

  def pre_process_table_rows(data, options = {})
    x = options[:at][0] + @relative[0]
    y = options[:at][1] + @relative[1]
    headers = options[:headers]
    max_rows_count = options[:max_rows_count]
    font_size = options[:size] || 8

    table_width = @paper_width - 2*x
    col_width_arr = (options[:col_width_arr])? options[:col_width_arr] : calculate_table_column_width(table_width, data, options)

    # ---

    default_row_height = (font_size / 2)
    total_rows_count = 0

    if headers
      total_rows_count += 1
    end

    extra_rows_count = 0 # "extra" means we need more height when break line happened
    data.each_with_index do |row_data, row_index|
      extra_rows_count_candidate = [] # we will choose a max extra_rows_count every row
      total_rows_count += 1
      return data.last( data.size - row_index).clone if total_rows_count > max_rows_count # split point

      row_data.each_with_index do |col_data, col_index|
        extra_rows_count_in_this_col = split_to_array( col_data, col_width_arr[col_index] ).size
        extra_rows_count_candidate << extra_rows_count_in_this_col
      end

      max_extra_rows_count_in_this_row = extra_rows_count_candidate.max

      extra_rows_count = extra_rows_count + max_extra_rows_count_in_this_row
      total_rows_count += (max_extra_rows_count_in_this_row == 0 )? 0 : max_extra_rows_count_in_this_row - 1
    end

    return nil
  end

end
