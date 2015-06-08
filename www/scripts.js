var prefix = "/api/server/";
var N = 100;
var M = 100;
var shown = 0;
const cellOffset = 60;
var symbols =["X", "O", "*", "&", "%", "V", "#", "@", ">", "<"];
$(document).ready(function()
{
    var players = [];//player data array
    var dialog = document.querySelector('dialog');//our dialog
    var divs = {
        div:[], x:[], y:[]
    };//array of divs that contains x y and div

    create_field();
    setInterval(update_players,1000);
    setInterval(update_field,1000);
    setInterval(update_winner,1000);

    function create_field() {
        var field = $('#field');
        var i = 0;

        for (var x = 0; x <= N; x++)
        {
            for (var y = 0; y <= M; y++)
            {
                var st = "<div class='cell' X='%1' Y='%2' style='top:p_tpx; left:p_lpx;'>";
                st = st.replace("%1", x);
                st = st.replace("%2", y);
                st = st.replace("p_t", cellOffset * y);
                st = st.replace("p_l", cellOffset * x);
                field.append(st);

                i++;
            }
        }
    }

    $(".cell").click(function(event){
        var name = $("#name").val();
        var X = $(this).attr("X");
        var Y = $(this).attr("Y");
        make_turn(name,X,Y);
    });

    function join() {
        var name = $("#name").val();
        var input = $("#name");
        if (name.length > 0) {
            $.ajax({
                url: prefix + "join/" + name ,
                dataType: "text"
            }).done(function (str) {
                if ("ok" == str) {
                    $("#button").attr("status","leave");
                    input.attr('disabled',true);
                    $("#button").removeClass("btn-primary").addClass("btn-danger").text("Leave Game");
                }
                else if (str == "not_ok"){
                    document.getElementById("dialog_text").innerHTML = "CHOOSE ANOTHER NAME";
                    dialog.showModal();
                }
            });

        }
        else{
            document.getElementById("dialog_text").innerHTML = "ENTER NAME";
            dialog.showModal();
        }
    }

    function leave() {
        var inp = $("#name");
        var name = $("#name").val();
        if (name.length > 0) {
            $.ajax({
                url: prefix + "leave/" + name,
                dataType:"text"
            }).done(function(str){
                if (str == "ok"){
                    $("#button").attr("status","join");
                    inp.val("");
                    inp.attr("disabled", false);
                    $("#button").removeClass("btn-danger").addClass("btn-primary").text("JOIN GAME");
                }
            });
        }
    }

    $("#button").click(function(){
        var inp = $("#name");
        var status = $(this).attr("status");
        if (status == "join") {
            join();
        }
        else {
            leave();
        }
    });

    $("#button_reset").click(function(){
        reset();
    });

    function update_players() {
        var list_html = $("#list");

        $.ajax({
            url: prefix + "who_plays",
            dataType: "json"
        }).done(function(data) {
            var players_list = data.players;

            var html = "";

            for (var i = 0; i < players_list.length; i++)
            {

                var player = players_list[i];
                var symbol = cur_symbol(i);

                if(has_player(player)!=1)
                    players.push({symbol:symbol,name:player});

                html = html + "<li>" + players[i].name + ": " + players[i].symbol+  "</li>";
            }
            list_html.html(html);
        });
    }

    function has_player(name){
        for (var i = 0; i < players.length; i++)
        {

            if (players[i].name == name) {
                return 1;
            }
        }
        return 0;
    }
    function symbol_of_player(name)
    {
        for (var i = 0; i < players.length; i++)
        {
            if (players[i].name == name) {
                return players[i].symbol;
            }
        }
        return "";
    }

    function cur_symbol(ind){
        if (ind < symbols.length){
            return symbols[ind];
        }
        else {
            return "" + 1;
        }
    }

    function update_field() {
        $.ajax({
            url: prefix + "get_field",
            dataType: "json"
        }).done(function(data) {
            var field = data;
            for (var i = 0; i < field.length; i++)
            {
                var cell = field[i];
                var symbol = symbol_of_player(cell.player);
                var l=".cell[x='"+cell.x+"'][y='"+cell.y+"']";
                $(l).text(symbol)
            }
        });
    }

    function update_winner() {
        $.ajax({
            url: prefix + "who_won",
            dataType: "json"
        }).done(function(data) {
            var name = $("#name").val();

            if (data.winner == name && shown == 0){
                shown = 1;
                document.getElementById("dialog_text").innerHTML = "YOU WIN NIGGA!!!";
                dialog.showModal();
            }
            else if (data.winner != "no" && shown == 0) {
                shown = 1;
                document.getElementById("dialog_text").innerHTML = "LOOOOOSER";
                dialog.showModal();
            }
        });
    }

    function make_turn(name,X,Y)
    {
        if(players.length == 1)
        {
            document.getElementById("dialog_text").innerHTML = "FIND YORSELF A FRIEND MOTHERFUCKER";
            dialog.showModal();
            return;
        }

        $.ajax({
            url: prefix + "make_turn" +"/" + name + "/" + X + "/" + Y,
            dataType: "text"
        }).done(function(data){
            if (data == "end_game") {
                update_field();
            }
            else if (data == "no_winner"){
                update_field();
            }
            else if (data == "not_your_turn")
            {
                document.getElementById("dialog_text").innerHTML = "NOT YOUR TURN NIGGA";
                dialog.showModal();
            }
            else if (data == "busy")
            {
                document.getElementById("dialog_text").innerHTML = "GET THE FUCK OUT";
                dialog.showModal();
            }
        });
    }

    function reset(){
        $.ajax({
            erl: prefix + "reset",
            dataType: "text"
        }).done(function(data){
            if (data == "ok")
            {

            }
        });
    }
})