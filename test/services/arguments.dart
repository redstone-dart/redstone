library arguments;

import 'package:bloodless/server.dart' as app;

@app.Route("/args/:arg1/:arg2/:arg3")
pathArgs(String arg1, int arg2, [double arg3, String arg4, String arg5 = "arg5"]) =>
    {"arg1": arg1, "arg2": arg2, "arg3": arg3, "arg4": arg4, "arg5": arg5};
    
@app.Route("/named_args/:arg1/:arg2")
namedPathArgs(String arg1, {String arg2, String arg3, String arg4: "arg4"}) =>
    {"arg1": arg1, "arg2": arg2, "arg3": arg3, "arg4": arg4};
    
@app.Route("/query_args")
queryArgs(@app.QueryParam("arg1") String arg1, 
          @app.QueryParam("arg2") int arg2, 
          [@app.QueryParam("arg3") double arg3, 
           @app.QueryParam("arg4") String arg4, 
           @app.QueryParam("arg5") String arg5 = "arg5",
           String arg6, String arg7 = "arg7"]) =>
    {"arg1": arg1, "arg2": arg2, "arg3": arg3, "arg4": arg4, "arg5": arg5, "arg6": arg6, "arg7": arg7};

@app.Route("/named_query_args")
namedQueryArgs(@app.QueryParam("arg1") String arg1,
               {@app.QueryParam("arg2") String arg2,
                @app.QueryParam("arg3") String arg3,
                @app.QueryParam("arg4") String arg4: "arg4",
                String arg5, String arg6: "arg6"}) =>
    {"arg1": arg1, "arg2": arg2, "arg3": arg3, "arg4": arg4, "arg5": arg5, "arg6": arg6};

@app.Route("/path_query_args/:arg")
pathAndQueryArgs(String arg, @app.QueryParam("arg") String qArg) =>
    {"arg": arg, "qArg": qArg};
    
@app.Route("/json/:arg", methods: const [app.POST])
jsonBody(String arg, @app.Body(app.JSON) Map json) => {"arg": arg, "json": json};
    
@app.Route("/form/:arg", methods: const [app.POST])
formBody(String arg, @app.Body(app.FORM) Map form) => {"arg": arg, "form": form};    
    
    
    
    