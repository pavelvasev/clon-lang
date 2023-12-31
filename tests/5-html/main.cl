import std="std/std.cl" dom="std/dom/dom.cl"

obj "main" {
  output: cell

  root: dom.element "div" style="display: flex;flex-direction: column;" {
    dom.element "h3" "Input:"
    input_space: dom.element "textarea" style="height: 300px;"
    btn: dom.element "button" "Visualize!"
    
    dom.element "h3" "Output:"

    output_space: dom.element "div" style="border: 1px solid grey" 

    //reaction (dom.event @btn.output "click") {:  :}

    reaction (dom.event @btn "click") "() => {
      let odom = output_space.output.get()
      let idom = input_space.output.get()
      odom.textContent = idom.value
    }"
    
    /*
    clicked: dom.event @btn.output "click"

    clickedm: method "() => {
      let odom = output_space.output.get()
      let idom = input_space.output.get()
      odom.textContent = idom.value
      }"

    bind @clicked @clickedm  
    */

  }
  bind @root @output
}