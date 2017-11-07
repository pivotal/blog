---
authors:
- peter
categories:
- vim
date: 2017-11-04T17:16:22Z
draft: true
short: |
  A subset of useful vim commands for beginners
title: All I do is VIM VIM VIM
---

{{< responsive-figure src="/images/vim/win.gif" class="medium center" >}}
I love keyboard shortcuts. Naturally, VIM would be my best friend but it was really hard to get into. While pair programming at Pivotal with expert VIMists (is that a word?) I got to learn a few tricks. Below I've gathered a subset of vim commands that have converted me. Think of it as "just enough vim" to get very comfortable.

I assume you understand the difference between insert, visual and normal mode.

# Movement

<table>
  <tr>
    <td colspan="2">
      `j`, `k`, `h` and `l` will move your cursor down, up, left and right respectively
    </td>
  </tr>
  <tr>
    <td style="width: 50%">{{< responsive-figure src="/images/vim/j.gif" class="small" >}}</td>
  <td>{{< responsive-figure src="/images/vim/k.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>{{< responsive-figure src="/images/vim/h.gif" class="small" >}}</td>
    <td>{{< responsive-figure src="/images/vim/l.gif" class="small" >}}</td>
  </tr>
  <tr>
  <td style="width: 50%">
    `gg` will jump you to the top of the file </td>
    <td> {{< responsive-figure src="/images/vim/gg.gif" class="small" >}} </td>
  </tr>
  <tr>
    <td>`G` will jump you to the bottom of the file</td>
    <td>{{< responsive-figure src="/images/vim/g.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>`0` will move you to the front of the line</td>
    <td>{{< responsive-figure src="/images/vim/0.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>`$` will move you to the end of the line</td>
    <td>{{< responsive-figure src="/images/vim/dollar.gif" class="small" >}}</td>
  </tr>
</table>

# Editing

<table>
  <tr>
    <td style="width: 50%">`dd` deletes the line your cursor is on</td>
    <td>{{< responsive-figure src="/images/vim/dd.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>`x` deletes the character you cursor is on </td>
    <td>{{< responsive-figure src="/images/vim/x.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>`D` deletes all the characters from your cursor to the end of the line </td>
    <td>{{< responsive-figure src="/images/vim/D.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>`r` + "some character" will replace the character your cursor is on with "some-character"</td>
    <td>{{< responsive-figure src="/images/vim/r.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>`p` will paste what you've copied in the line below your cursor</td>
    <td>{{< responsive-figure src="/images/vim/p.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>`P` will paste what you've copied in the line above your cursor</td>
    <td>{{< responsive-figure src="/images/vim/shiftp.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>`y` will copy the highlighted text</td>
    <td>{{< responsive-figure src="/images/vim/y.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>`yy` will copy the line your cursor is on</td>
    <td>{{< responsive-figure src="/images/vim/yy.gif" class="small" >}}</td>
  </tr>
</table>

## "Scrolling"

<table>
  <tr>
    <td style="width: 50%">I use these two often to "scroll" through a file. `{` will move your cursor to the next empty new line above your cursor</td>
    <td>{{< responsive-figure src="/images/vim/previousempty.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>`}` will move your cursor to the next empty new line below your cursor</td>
    <td>{{< responsive-figure src="/images/vim/nextempty.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>Alternatively you can use `ctrl+f` or `cftrl+b` to scroll to the previous or next "page" where page is the amount of lines that your screen can fit. I find i don't use this as often.</td>
    <td>
      {{< responsive-figure src="/images/vim/pagef.gif" class="small" >}}
      {{< responsive-figure src="/images/vim/pageb.gif" class="small" >}}
    </td>
  </tr>
</table>

## Switching to insert mode


<table>
  <tr>
    <td style="width: 50%">`a` puts your cursor in insert mode after the character the cursor was on. `i` puts your cursor in insert mode before the character the cursor was on.</td>
    <td>
      {{< responsive-figure src="/images/vim/a.gif" class="small" >}}
      {{< responsive-figure src="/images/vim/i.gif" class="small" >}}
    </td>
  </tr>
  <tr>
    <td>`A` puts your cursor in insert mode at the end of the current line. `I` puts your cursor in insert mode at the beginning of the line.
      <br />
      To remember which is which I tell myself that `a` stands for append and `i` ... is the other one.
    </td>
    <td>
      {{< responsive-figure src="/images/vim/shifta.gif" class="small" >}}
      {{< responsive-figure src="/images/vim/shifti.gif" class="small" >}}
    </td>
  </tr>
  <tr>
    <td>`o` puts you in insert mode on a new line below your current line. `O` puts you in insert mode on a new line above your current line.</td>
    <td>
      {{< responsive-figure src="/images/vim/o.gif" class="small" >}}
      {{< responsive-figure src="/images/vim/shifto.gif" class="small" >}}
    </td>
  </tr>
</table>

## Text manipulation

<table>
  <tr>
    <td style="width: 50%">`ciw` will delete the word you're  cursor is on and put you in insert mode. I remember this as "change in word"</td>
    <td>{{< responsive-figure src="/images/vim/ciw.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>`viw` is similar to `ciw` but only highlights the word and puts you in visual mode. I remember this as "view in word"</td>
    <td>{{< responsive-figure src="/images/vim/viw.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>`d/` + "some-characters" + `enter` will delete characters from your cursor to "some-characters". This is equivalent to highlighting and deleting part of a line in say sublime.</td>
    <td>{{< responsive-figure src="/images/vim/dslash.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>`J` will delete and append the line below your cursor the end of your current line. It's handy when you want to "glue" together some lines of text.</td>
    <td>{{< responsive-figure src="/images/vim/shiftj.gif" class="small" >}}</td>
  </tr>
</table>

## Commands

As a quick summary for complete beginners to VIM, you can enter commands while in normal mode by type `:` followed by the command and `enter`. Here are some basic ones everyone should know.

`:w` saves the current file. I remember it as "writes" the file.

`:q` quits the file.

`:wq` saves the file and quits the file. `:x` is equivalent. Not sure why it exists but I use it often.

`:qa` quits all the buffers.

<table>
  <tr>
    <td style="width: 50%">`:set cursorcolumn` creates a highlight bar on the column your cursor is on. It's just a visual aid which is helpful to check your tabbing is okay.</td>
    <td>{{< responsive-figure src="/images/vim/cursorcolumn.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>`:set nu` turns on line numbers. It's actually short for `:set number` which is easier to remember.</td>
    <td>{{< responsive-figure src="/images/vim/nu.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>`:set nonu` turns off line numbers. There is also an equivalent `:set nonumber`.</td>
    <td>{{< responsive-figure src="/images/vim/nonu.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>`:e <filename>` will open up a file you type in. </td>
    <td>{{< responsive-figure src="/images/vim/colone.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>Use `ctrl+o` to move to the previously opened file or `ctrl+i` to move to the next opened file.</td>
    <td>{{< responsive-figure src="/images/vim/io.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>`:set wrap` turns on wordwrapper. Handy when you're editing paragraphs of text and not code. `:set nowrap` will undo the wordwrapper.</td>
    <td>{{< responsive-figure src="/images/vim/wrap.gif" class="small" >}}</td>
  </tr>
</table>

When you're pasting blocks of text from outside of vim, you should run `:set paste` to prevent vim auto inserting tabs in your text.

### Find / Search

<table>
  <tr>
    <td style="width: 50%">`/` following by a word searches your file for that word. </td>
    <td>{{< responsive-figure src="/images/vim/slash.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>Type `n` to move your cursor to the next instance of that word. `N` will move your cursor to the previous one. </td>
    <td>
      {{< responsive-figure src="/images/vim/n.gif" class="small" >}}
      {{< responsive-figure src="/images/vim/shiftn.gif" class="small" >}}
    </td>
  </tr>
  <tr>
    <td>A fun fact I later learnt about this is that even after you start editing or move your cursor to another line, `n` and `N` will still work for the last word you searched for.</td>
    <td>{{< responsive-figure src="/images/vim/moren.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>When you do a find/search vim will highlight that text. Use `:noh` to remove this highlight. I remember it as "no highlight".</td>
    <td>{{< responsive-figure src="/images/vim/noh.gif" class="small" >}}</td>
  </tr>
</table>

### Multiple windows

<table>
  <tr>
    <td style="width: 50%">`:sp` is a handy command that will split your window into two horizontally. (I remember it as "**sp**litting" the window) This is convenient for when you want to look at two different files at the same time. I often follow `:sp` with `:e` to open up new files.</td>
    <td>{{< responsive-figure src="/images/vim/sp.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>I more commonly use `:vs` which I remember as a vertical split. This splits the screen side by side.</td>
    <td>{{< responsive-figure src="/images/vim/vs.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>To move around windows you can use `ctrl+w ctrl+w` to toggle your cursor between open windows. To be more exact you can use `ctrl+w (j/k/h/l)` to move in a specific window to the bottom, top, left or right.</td>
      <td>
        {{< responsive-figure src="/images/vim/ww.gif" class="small" >}}
        {{< responsive-figure src="/images/vim/wjk.gif" class="small" >}}
      </td>
  </tr>
</table>

#### Quickly highlight blocks of texts

<table>
  <tr>
    <td style="width: 50%">`V` will highlight the entire line your cursor is on. Follow through with movements like `j`, `k`, `{` or `}` to highlight large blocks of text. </td>
    <td>
      {{< responsive-figure src="/images/vim/shiftv.gif" class="small" >}}
      {{< responsive-figure src="/images/vim/shiftvplus.gif" class="small" >}}
    </td>
  </tr>
</table>


## Fancy stuff

So there are a few handy moves that I don't know where to put. They are definitely beyond the basics.

<table>
  <tr>
    <td style="width: 50%">`:%s/existing-string/new-string/g` Will find all instances of "existing-string" and replace it with "new-string"</td>
    <td>{{< responsive-figure src="/images/vim/percents.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>A variation of the above is `:%s/existing-string/new-string/gc` which replaces instances of "existing-string" one by one but asks you to confirm first. Hit `y` to accept, hit `n` to skip.</td>
    <td>{{< responsive-figure src="/images/vim/percentsc.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>There is this multicursor command: `ctrl+v (j/k/h/l)`. This allows you to select the current column among multiple lines.</td>
    <td>{{< responsive-figure src="/images/vim/ctrlv.gif" class="small" >}}</td>
  </tr>
  <tr>
    <td>More interestingly once you've selected a set of lines, by typing `I <some chars> ESC`, you'll apply `<some chars>` to all the lines that were selecto confirm ted.</td>
    <td>{{< responsive-figure src="/images/vim/ctrlvplus.gif" class="small" >}}</td>
  </tr>
</table>

### Markers
<table>
  <tr>
    <td style="width: 50%">If you're editing a large file and are frequently jumping back and forward between two sections you can create markers to quickly jump between lines. `m<somechar>` will allow `` `<somechar>`` to jump to that line. (That's a backtick follow by some character). Run `:marks` to see the markers you've set.</td>
    <td>{{< responsive-figure src="/images/vim/marker.gif" class="small" >}}</td>
  </tr>
</table>


## Plugins

There are tons of plugins available for VIM that does very specific things. The one I suggest as a must have is [NERDTree](https://github.com/scrooloose/nerdtree). 

<table>
  <tr>
    <td style="width: 50%">You can use `|` (pipe) to jump from your current file to the tree. Or you can use the same keys for window navigation such as `ctrl+w h` to move to the window to the left since NERDTree is just another window.</td>
    <td>{{< responsive-figure src="/images/vim/pipe.gif" class="small" >}}</td>
  </tr>
</table>

# Conclusion

If you memorize this subset of commands I'm confident you'll begin to navigate VIM with ease...

And when I step into the building everybody's hands go ... on the keyboard
{{< responsive-figure src="/images/vim/hands.gif" class="medium center" >}}

