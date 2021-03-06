

var http_requests = [];
function ajax(url, func) {
  var i = 0;
  for(i=0; i<http_requests.length; i++)
    if(http_requests[i] == null)
      break;
  document.getElementById('loading').style.display = 'block';
  http_requests[i] = (window.ActiveXObject) ? new ActiveXObject('Microsoft.XMLHTTP') : new XMLHttpRequest();
  if(http_requests[i] == null) {
    alert("Your browse does not support the functionality this website requires.");
    return;
  }
  http_requests[i].onreadystatechange = function() {
    if(!http_requests[i] || http_requests[i].readyState != 4 || !http_requests[i].responseText)
      return;
    if(http_requests[i].status != 200)
      alert('Something seems to have gone wrong while saving the new configuration.');
    else
      func(http_requests[i]);
    http_requests[i] = null;
    for(i=0; i<http_requests.length; i++)
      if(http_requests[i] != null)
        break;
    if(i == http_requests.length)
      document.getElementById('loading').style.display = 'none';
  };
  url += (url.indexOf('?')>=0 ? ';' : '?')+(Math.floor(Math.random()*999)+1);
  http_requests[i].open('GET', url, true);
  http_requests[i].send(null);
}
function qq(v) {
  v = ''+v;
  return v.replace(/&/g,"&amp;").replace(/</,"&lt;").replace(/>/,"&gt;").replace(/"/g,'&quot;');
}



// creates an input container, positioned below obj
var input_obj = null;
function create_input(obj, submit, offheight, offwidth) {
  if(input_obj != null && input_obj.obj == obj) {
    remove_input();
    return null;
  }
  remove_input();

  // get coordinates of obj (relative to our content div)
  var x = offwidth == null ? 0 : offwidth;
  var y = offheight == null ? obj.offsetHeight : offheight;
  var c = document.getElementById('content');
  var o = obj;
  do {
    x += o.offsetLeft;
    y += o.offsetTop;
  } while((o = o.offsetParent) && o != c);

  // create input object
  input_obj = document.createElement('div');
  input_obj.style.position = 'absolute';
  input_obj.style.left = x+'px';
  input_obj.style.top = y+'px';
  input_obj.obj = obj;
  input_obj.id = 'input_obj';
  o.appendChild(input_obj);
  o = document.createElement('form');
  o.method = 'POST';
  o.onsubmit = submit == null ? null : function() { submit(this); return false };
  input_obj.appendChild(o);
  return o;
}
function remove_input() {
  if(input_obj)
    document.getElementById('content').removeChild(input_obj);
  input_obj = null;
}
function click_input(e) {
  e = e || window.event;
  var tg = e.target || e.srcElement;
  while(tg && (tg.nodeType == 3 || tg.nodeName.toLowerCase() != 'div' || !tg.id || tg.id != 'input_obj'))
    tg = tg.parentNode;
  if(tg == null)
    remove_input();
  return true;
}


function conf_set(page, item, field, value, obj) {
  conf_set_remove(page, item, field, value, obj, 1);
}

function ajax_timed_write(obj, resp_text) {
  var i=0;
  obj.innerHTML = "Writing... (7)";
  setTimeout( function() {
    obj.innerHTML = "Writing... (6)";
  }, 1000);
  setTimeout( function() {
    obj.innerHTML = "Writing... (5)";
  }, 2000);
  setTimeout( function() {
    obj.innerHTML = "Writing... (4)";
  }, 3000);
  setTimeout( function() {
    obj.innerHTML = "Writing... (3)";
  }, 4000);
  setTimeout( function() {
    obj.innerHTML = "Writing... (2)";
  }, 5000);
  setTimeout( function() {
    obj.innerHTML = "Writing... (1)";
  }, 6000);
  setTimeout( function() {
    obj.innerHTML = resp_text;
  }, 7000);
}

function conf_set_remove(page, item, field, value, obj, remove) {
  if(obj == null)
    obj = this;
  while((obj.nodeName.toLowerCase() != 'td') && (obj.nodeName.toLowerCase() != 'th'))
    obj = obj.parentNode;
//  alert('/ajax/'+page+'?item='+item+';field='+field+';'+field+'='+encodeURIComponent(value));
  ajax('/ajax/'+page+'?item='+item+';field='+field+';'+field+'='+encodeURIComponent(value), function(h) {
    if (remove) {
      remove_input(input_obj);
    }
    if (page == 'config/users/write') {
      ajax_timed_write(obj, h.responseText);
    } else {
      obj.innerHTML = h.responseText;
    }
    if((((page == 'config/source') || (page == 'config/users') || (page == 'config/preset') ||
         (page == 'config/dest') || (page == 'config/consolepreset') || (page == 'config/busspreset') ||
         (page == 'system')) && (field == 'pos')) || (page == 'system/account') ||
         ((page == 'system') && (item == 'all')) ||
         ((page.match('^config/setuserlevel') == 'config/setuserlevel') && (item == 'all'))
      )
    {
      location.reload(true);
    }
  });
  return false;
}


function conf_number(unit, page, item, field, value, obj) {
  var d = create_input(obj, function(f) {
    var val = f.getElementsByTagName('input')[0].value;
    if(isNaN(parseFloat(val)))
      return alert('Invalid number');
    conf_set(page, item, field, val, obj);
  });
  if(!d) return false;
  d.innerHTML = '<input type="text" value="'+qq(value)+'" size="6" class="text">'+unit
    +' <input type="submit" value="Save" class="button" />';
  d = d.getElementsByTagName('input')[0];
  d.focus();
  d.select();
  return false;
}


function conf_level(page, item, field, value, obj) { return conf_number('dB', page, item, field, value, obj); }
function conf_freq( page, item, field, value, obj) { return conf_number('Hz', page, item, field, value, obj); }
function conf_proc( page, item, field, value, obj) { return conf_number('%',  page, item, field, value, obj); }


function conf_text(page, item, field, value, obj, textname, buttonname) {
  var d = create_input(obj, function(f) {
    conf_set(page, item, field, f.getElementsByTagName('input')[0].value, obj);
  });
  if(!d) return false;
  var size = value.length > 10 ? value.length+5 : 10;
  d.innerHTML = '';
  if(textname) d.innerHTML += textname;
  d.innerHTML += '<input type="text" value="'+qq(value)+'" size="'+size+'" class="text">';
  if(buttonname) {
    d.innerHTML += '<input type="submit" value="'+buttonname+'" class="button" />';
  } else {
    d.innerHTML += '<input type="submit" value="Save" class="button" />';
  }
  d = d.getElementsByTagName('input')[0];
  d.focus();
  d.select();
  return false;
}

function conf_pass(page, item, field, value, obj, textname, buttonname) {
  var d = create_input(obj, function(f) {
    conf_set(page, item, field, f.getElementsByTagName('input')[0].value, obj);
  });
  if(!d) return false;
  var size = value.length > 10 ? value.length+5 : 10;
  d.innerHTML = '';
  if(textname) d.innerHTML += textname;
  d.innerHTML += '<input type="password" value="'+qq(value)+'" size="'+size+'" class="text">';
  if(buttonname) {
    d.innerHTML += '<input type="submit" value="'+buttonname+'" class="button" />';
  } else {
    d.innerHTML += '<input type="submit" value="Save" class="button" />';
  }
  d = d.getElementsByTagName('input')[0];
  d.focus();
  d.select();
  return false;
}


function conf_select(page, item, field, value, obj, list, listname, buttonname) {
  var d = create_input(obj, function(f) {
    var s = f.getElementsByTagName('select')[0];
    conf_set(page, item, field, s.options[s.selectedIndex].value, obj);
  });
  if(!d) return false;
  d.innerHTML = '';
  if (listname) d.innerHTML += listname;
  d.innerHTML += document.getElementById(list).innerHTML;
  if (buttonname) {
    d.innerHTML += '<input type="submit" value="'+buttonname+'" class="button" />';
  } else {
    d.innerHTML += '<input type="submit" value="Save" class="button" />';
  }
  d = d.getElementsByTagName('select')[0];
  d.style.display = 'inline';
  for(var i=0; i<d.length; i++)
    if(d.options[i].value == value)
      d.options[i].selected = true;
  d.focus();
  return false;
}


/* this is an actual form, doesn't use AJAX */
function conf_addsrc(obj, list, type) {
  var d = create_input(obj, null, -70);
  if(!d) return false;

  var uctype = type.substr(0,1).toUpperCase() + type.substr(1,type.length);
  d.style.textAlign = 'right';
  d.innerHTML =
    '<label for="'+type+'1" >'+uctype+' 1 (left):</label>'+document.getElementById(list).innerHTML+'<br />'
   +'<label for="'+type+'2">'+uctype+' 2 (right):</label>'+document.getElementById(list).innerHTML+'<br />'
   +'<label for="label">Label:</label><input type="text" class="text" name="label" id="label" size="10" />'
   +' <input type="submit" value="Create" class="button" />';
  d = d.getElementsByTagName('select');
  d[0].name = d[0].id = type+'1';
  d[1].name = d[1].id = type+'2';
  d[0].style.width = d[1].style.width = '350px';
  return false;
}

/* this is an actual form, doesn't use AJAX */
function conf_addpreset(obj, button_text, preset_number) {
  var d = create_input(obj, null, -30);
  if(!d) return false;

  if(!preset_number) preset_number = 0;

  d.style.textAlign = 'right';
  d.innerHTML =
    '<label for="label">Label:</label><input type="text" class="text" name="label" id="label" size="10" value="Preset"/>'
   +'<input name="preset" type="hidden" value="'+preset_number+'"/>'
   +'<input type="submit" value="'+button_text+'" class="button" />';
  d = d.getElementsByTagName('select');
  return false;
}

/* this is an actual form, doesn't use AJAX */
function conf_adduser(obj, button_text) {
  var d = create_input(obj, null, -30);
  if(!d) return false;

  d.style.textAlign = 'right';
  d.innerHTML =
    '<label for="label">Username:</label><input type="text" class="text" name="username" id="label" size="10" value="New user"/><BR/>'
   +'<label for="label">Password:</label><input type="password" class="text" name="password" id="label" size="10"/><BR/>'
   +'<input type="submit" value="'+button_text+'" class="button" />';
  d = d.getElementsByTagName('select');
  return false;
}

function conf_eq(page, obj, item) {
  var d = create_input(obj, function (o) {
    var val = '';
    var l = o.getElementsByTagName('input');
    for(var i=0; i<l.length; i++)
      if(l[i].name)
        val += ';'+l[i].name+'='+encodeURIComponent(l[i].value);
    l = o.getElementsByTagName('select');
    for(i=0; i<l.length; i++)
      val += ';'+l[i].name+'='+encodeURIComponent(l[i].options[l[i].selectedIndex].value);
    val = val.substr(1, val.length-1);
    ajax('/ajax/'+page+'/'+item+'/eq?'+val, function(h) {
      document.getElementById('eq_table_container').innerHTML = h.responseText;
      remove_input(input_obj);
    });
  }, 0, obj.offsetWidth);
  if(!d) return false;
  d.innerHTML = document.getElementById('eq_table_container').innerHTML;
  d.getElementsByTagName('table')[0].id = 'eq_table';
  return false;
}

function conf_rtng(page, obj, item) {
  var d = create_input(obj, function (o) {
    var val = '';
    var l = o.getElementsByTagName('input');
    for(var i=0; i<l.length; i++)
      if(l[i].name)
        val += ';'+l[i].name+'='+encodeURIComponent(l[i].value);
    l = o.getElementsByTagName('select');
    for(i=0; i<l.length; i++)
      val += ';'+l[i].name+'='+encodeURIComponent(l[i].options[l[i].selectedIndex].value);
    val = val.substr(1, val.length-1);
    ajax('/ajax/'+page+'/'+item.toUpperCase()+'?'+val, function(h) {
      document.getElementById('routing_'+item+'_table_container').innerHTML = h.responseText;
      remove_input(input_obj);
    });
  }, 0, obj.offsetWidth);
  if(!d) return false;
  d.innerHTML = document.getElementById('routing_'+item+'_table_container').innerHTML;
  d.getElementsByTagName('table')[0].id = 'routing_table';
  return false;
}

function conf_dyn(page, obj, item) {
  var d = create_input(obj, function (o) {
    var val = '';
    var l = o.getElementsByTagName('input');
    for(var i=0; i<l.length; i++)
      if(l[i].name)
        val += ';'+l[i].name+'='+encodeURIComponent(l[i].value);
    l = o.getElementsByTagName('select');
    for(i=0; i<l.length; i++)
      val += ';'+l[i].name+'='+encodeURIComponent(l[i].options[l[i].selectedIndex].value);
    val = val.substr(1, val.length-1);
    ajax('/ajax/'+page+'/'+item+'/dyn?'+val, function(h) {
      document.getElementById('dyn_table_container').innerHTML = h.responseText;
      remove_input(input_obj);
    });
  }, 0, obj.offsetWidth);
  if(!d) return false;
  d.innerHTML = document.getElementById('dyn_table_container').innerHTML;
  d.getElementsByTagName('table')[0].id = 'dyn_table';
  return false;
}


function conf_func(addr, nr, f1, f2, f3, sensor, actuator, obj) {
  var i;var l;var o;
  var d = create_input(obj, function(f) {
    l = document.getElementById('func_main').getElementsByTagName('select')[0];
    f1 = l.options[l.selectedIndex].value;
    l = document.getElementById('func_'+f1);
    if(!l) {
      f2 = f3 = 0;
    } else {
      l = l.getElementsByTagName('select');
      f2 = f1 == 4 ? 0 : l[0].options[l[0].selectedIndex].value;
      f3 = l[f1==4?0:1].options[l[f1==4?0:1].selectedIndex].value;
    }
    while(obj.nodeName.toLowerCase() != 'td')
      obj = obj.parentNode;
    ajax('/ajax/config/setfunc?addr='+addr+';nr='+nr
        +';function='+f1+','+f2+','+f3+';sensor='+sensor+';actuator='+actuator, function(h) {
      obj.innerHTML = h.responseText;
      remove_input(input_obj);
    });
  });
  if(!d) return false;
  d.innerHTML = 'loading function list...';
  ajax('/ajax/config/func?sensor='+sensor+';actuator='+actuator, function(h) {
    d.innerHTML = h.responseText + '<input type="submit" value="Save" class="button" />';
    l = d.getElementsByTagName('div');
    for(i=0; i<l.length; i++)
      if(l[i].id != 'func_main' && l[i].id != 'func_'+f1)
        l[i].className = 'hidden';
    l = document.getElementById('func_main').getElementsByTagName('select')[0];
    for(i=0; i<l.options.length; i++)
      l.options[i].selected = l.options[i].value == f1;
    l.onchange = function() {
      f1 = this.options[this.selectedIndex].value;
      l = d.getElementsByTagName('div');
      for(i=0; i<l.length; i++)
        l[i].className = l[i].id != 'func_main' && l[i].id != 'func_'+f1 ? 'hidden' : '';
    };
    l = document.getElementById('func_'+f1);
    if(l) {
      l = l.getElementsByTagName('select');
      o = f1 == 4 ? l[0] : l[1];
      for(i=0; i<o.options.length; i++)
        o.options[i].selected = o[i].value == f3;
      if(f1 != 4)
        for(i=0,o=l[0].options; i<o.length; i++)
          o[i].selected = o[i].value == f2;
    }
  });
  return false;
}

function conf_id(addr, man_id, prod_id, firm_major, obj) {
  var selected_id, l, i;
  var d = create_input(obj, function(f) {
    l = document.getElementById('id_main').getElementsByTagName('select')[0];
    selected_id = l.options[l.selectedIndex].value;
    while(obj.nodeName.toLowerCase() != 'td')
      obj = obj.parentNode;
    ajax('/ajax/system/change_conf?addr='+addr+';man='+man_id
        +';prod='+prod_id+';id='+selected_id+';firm_major='+firm_major, function(h) {
      obj.innerHTML = h.responseText;
      remove_input(input_obj);
      location.reload(true);
    });
  });
  if(!d) return false;
  d.innerHTML = 'loading id list...';
  ajax('/ajax/system/id_list?man='+man_id+';prod='+prod_id+';firm_major='+firm_major, function(h) {
    d.innerHTML = h.responseText + '<input type="submit" value="Save" class="button" />';
    l = d.getElementsByTagName('div');
    l = document.getElementById('id_main').getElementsByTagName('select')[0];
    for(i=0; i<l.options.length; i++)
      l.options[i].selected = l.options[i].value == selected_id;
  });
  return false;
}

function conf_predefined(addr, obj) {
  var i;var l;var o;
  var v1; var v2;
  var d = create_input(obj, function(f) {
    l = document.getElementById('pre_main').getElementsByTagName('select')[0];
    v1 = l.options[l.selectedIndex].value;
    l = document.getElementById('pre_main').getElementsByTagName('input')[0];
    v2 = l.value;

    while(obj.nodeName.toLowerCase() != 'td')
      obj = obj.parentNode;
    ajax('/ajax/config/setpre?addr='+addr+';predefined='+encodeURIComponent(v1)+';offset='+v2, function(h) {
      obj.innerHTML = h.responseText;
      remove_input(input_obj);
    });
  });
  if(!d) return false;
  d.innerHTML = 'loading configuration list...';
  ajax('/ajax/config/loadpre?addr='+addr, function(h) {
    d.innerHTML = h.responseText + ' Offset<input type="text" id="seq" maxlength="4" size="4" value="0"> <input type="submit" value="Import" class="button" />';
    l = d.getElementsByTagName('div');
    for(i=0; i<l.length; i++)
      if(l[i].id != 'pre_main')
        l[i].className = 'hidden';
    l = document.getElementById('pre_main').getElementsByTagName('select')[0];
    l.onchange = function() {
      f1 = this.options[this.selectedIndex].value;
      l = d.getElementsByTagName('div');
    };
  });
  return false;
}


function exp_over() {
  var str_array = this.className.split(' ');
  var el = this.abbr ? this : document.getElementById(str_array[0]);
  if(el.over)
    return;
  el.over = 1;
  var tmp;
  tmp = el.abbr;
  el.abbr = el.innerHTML;
  el.innerHTML = tmp;
}
function exp_out() {
  var str_array = this.className.split(' ');
  var el = this.abbr ? this : document.getElementById(str_array[0]);
  tmp = el.abbr;
  el.abbr = el.innerHTML;
  el.innerHTML = tmp;
  el.over = 0;
}

function exp_over_a() {
  var str_array = this.className.split(' ');
  var el = this.title ? this : document.getElementById(str_array[0]);
  if(el.over)
    return;
  el.over = 1;
  var tmp;
  tmp = el.title;
  el.title = el.innerHTML;
  el.innerHTML = tmp;
}
function exp_out_a() {
  var str_array = this.className.split(' ');
  var el = this.title ? this : document.getElementById(str_array[0]);
  tmp = el.title;
  el.title = el.innerHTML;
  el.innerHTML = tmp;
  el.over = 0;
}

window.onmousedown = click_input;

window.onload = function() {
  // look for all td/th/a tags with a class starting with exp_
  var i;
  var l = document.getElementsByTagName('td');
  for(i=0; i<l.length; i++)
    if(l[i].className.indexOf('exp_') == 0 || l[i].id.indexOf('exp_') == 0) {
      l[i].onmouseover = exp_over;
      l[i].onmouseout = exp_out;
    }
  l = document.getElementsByTagName('th');
  for(i=0; i<l.length; i++)
    if(l[i].className.indexOf('exp_') == 0 || l[i].id.indexOf('exp_') == 0) {
      l[i].onmouseover = exp_over;
      l[i].onmouseout = exp_out;
    }
  l = document.getElementsByTagName('a');
  for(i=0; i<l.length; i++)
    if(l[i].className.indexOf('exp_') == 0 || l[i].id.indexOf('exp_') == 0) {
      l[i].onmouseover = exp_over_a;
      l[i].onmouseout = exp_out_a;
    }
};

function msg_box(textstring, url) {
  if (confirm(textstring)){
    location = url;
  }
}

function conf_tz( obj) {
  var i;var l;var o;var m;
  var cont_nr = 0;
  var area_nr = 0;
  var d = create_input(obj, function(f) {
    l = document.getElementById('tz_main').getElementsByTagName('select')[0];
    cont_nr = l.options[l.selectedIndex].value;
    m = document.getElementById('cont_'+cont_nr).getElementsByTagName('select')[0];
    area_nr = m.options[m.selectedIndex].value;
    n = document.getElementById('region_'+cont_nr+'/'+area_nr).getElementsByTagName('select')[0];
    while(obj.nodeName.toLowerCase() != 'td')
      obj = obj.parentNode;
    ajax('/ajax/config/set_tz?tz='+n.options[n.selectedIndex].value, function(h) {
      obj.innerHTML = h.responseText;
      remove_input(input_obj);
    });
  });
  if(!d) return false;
  d.innerHTML = 'loading timezone list...';
  ajax('/ajax/config/tz_lst', function(h) {
    d.innerHTML = h.responseText + '<input type="submit" value="Save" class="button" />';
    l = d.getElementsByTagName('div');
    for(i=0; i<l.length; i++)
      if(l[i].id != 'tz_main' && l[i].id != 'cont_'+cont_nr && l[i].id != 'region_'+cont_nr+'/'+area_nr)
        l[i].className = 'hidden';

    l = document.getElementById('tz_main').getElementsByTagName('select')[0];
    for(i=0; i<l.options.length; i++)
      l.options[i].selected = l.options[i].value == cont_nr;

    l.onchange = function() {
      cont_nr = this.options[this.selectedIndex].value;
      l = d.getElementsByTagName('div');
      for(i=0; i<l.length; i++)
      {
        l[i].className = l[i].id != 'tz_main' && l[i].id != 'cont_'+cont_nr ? 'hidden': '';
      }
      for(i=0; i<l.length; i++) {
        if (l[i].id == 'cont_'+cont_nr) {
          l[i].getElementsByTagName('select')[0].onchange();
        }
      }
    };

    l = document.getElementById('tz_main').getElementsByTagName('select')[0];
    for(i=0; i<l.options.length; i++)
    {
      m = document.getElementById('cont_'+i).getElementsByTagName('select')[0];
      m.onchange = function() {
        n = document.getElementById('tz_main').getElementsByTagName('select')[0];
        cont_nr = n.options[n.selectedIndex].value;
        area_nr = this.options[this.selectedIndex].value;
        m = d.getElementsByTagName('div');
        for (j=0; j<m.length; j++)
        {
          m[j].className = m[j].id != 'tz_main' && m[j].id != 'cont_'+cont_nr ? 'hidden': '';
          if (m[j].id == 'region_'+cont_nr+'/'+area_nr) {
            if (m[j].getElementsByTagName('select')[0].options.length>1) {
              m[j].className = '';
            }
          }
        }
      }
    }
    l.onchange();
  });
  return false;
}

function toggle_visibility(id, obj)
{
  var l;
  l = document.getElementById(id);
  if (l.className == "") {
    l.className = "hidden";
  } else {
    l.className = "";
  }
  return false;
}

function conf_outputlist(item, field, selected_output, obj) {
  var selected_output, l, i;
  var d = create_input(obj, function(f) {
    l = document.getElementById('out_ch_main').getElementsByTagName('select')[0];
    selected_output = l.options[l.selectedIndex].value;
    while(obj.nodeName.toLowerCase() != 'td')
      obj = obj.parentNode;
    ajax('/ajax/config/dest?item='+item+';field='+field+';'+field+'='+encodeURIComponent(selected_output), function(h) {
      obj.innerHTML = h.responseText;
      remove_input(input_obj);
    });
  });
  if(!d) return false;
  d.innerHTML = 'loading slot/channel list...';
  ajax('/ajax/config/outputlist?current='+selected_output, function(h) {
    d.innerHTML = h.responseText + '<input type="submit" value="Save" class="button" />';
    l = d.getElementsByTagName('div');
    l = document.getElementById('out_ch_main').getElementsByTagName('select')[0];
    for(i=0; i<l.options.length; i++)
      l.options[i].selected = l.options[i].value == selected_output;
  });
  return false;
}

function conf_adddest(obj, list, type) {
  var d = create_input(obj, null, -70);
  if(!d) return false;
  d.innerHTML = 'loading slot/channel list...';
  ajax('/ajax/config/outputlist?current=0_0', function(h) {

  var uctype = type.substr(0,1).toUpperCase() + type.substr(1,type.length);
  d.style.textAlign = 'right';
  d.innerHTML =
    '<label for="'+type+'1" >'+uctype+' 1 (left):</label>'+h.responseText+'<br />'
   +'<label for="'+type+'2">'+uctype+' 2 (right):</label>'+h.responseText+'<br />'
   +'<label for="label">Label:</label><input type="text" class="text" name="label" id="label" size="10" />'
   +' <input type="submit" value="Create" class="button" />';
  d = d.getElementsByTagName('select');
  d[0].name = d[0].id = type+'1';
  d[1].name = d[1].id = type+'2';
  d[0].style.width = d[1].style.width = '350px';
  });
  return false;
}

