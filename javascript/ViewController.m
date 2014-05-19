//
//  ViewController.m
//  javascript
//
//  Created by Edson Teco on 05/05/14.
//  Copyright (c) 2014 CocoaHeadsBr. All rights reserved.
//  http://ramkulkarni.com/blog/calling-objective-c-function-from-javascript-in-ios-applications/

#import "ViewController.h"

@interface ViewController ()

@property (nonatomic, weak) IBOutlet UIWebView *webView;

@property (nonatomic, weak) IBOutlet UITextField *cor;
@property (nonatomic, weak) IBOutlet UIButton *botao;
@property (nonatomic, weak) IBOutlet UILabel *label;

@end

@implementation ViewController

#pragma mark -
#pragma mark Metodos privados

/**
 *  Método para identificar e executar as requisições
 *
 *  @param url URL para ser executada
 *
 *  @return YES para executar a URL caso seja um endereço web, NO para executar a função nativa
 */
- (BOOL)processURL:(NSString *)url
{
    NSString *urlStr = [NSString stringWithString:url];
    
    NSString *protocolPrefix = @"js2ios://";
    
    // Se o protocolo for o predefinido, executa
    //
    if ([[urlStr lowercaseString] hasPrefix:protocolPrefix])
    {
        // Separa o protocolo da URL.
        //
        urlStr = [urlStr substringFromIndex:protocolPrefix.length];
        
        // Decode da URL
        //
        urlStr = [urlStr stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        NSError *jsonError;
        
        // Parse JSON com a URL
        //
        NSDictionary *callInfo = [NSJSONSerialization
                                  JSONObjectWithData:[urlStr dataUsingEncoding:NSUTF8StringEncoding]
                                  options:kNilOptions
                                  error:&jsonError];
        
        // Verifica se houve erro ao fazer o parse do JSON
        //
        if (jsonError != nil) {
            NSLog(@"Error parsing JSON for the url %@",url);
            return NO;
        }
        
        // Obtém o nome da ação (obrigatório)
        //
        NSString *functionName = [callInfo objectForKey:@"functionname"];
        if (functionName == nil) {
            NSLog(@"Missing function name");
            return NO;
        }
        
        NSString *successCallback = [callInfo objectForKey:@"success"];
        NSString *errorCallback = [callInfo objectForKey:@"error"];
        NSArray *argsArray = [callInfo objectForKey:@"args"];
        
        [self callNativeFunction:functionName withArgs:argsArray onSuccess:successCallback onError:errorCallback];
        
        // Evita que essa URL seja executada no UIWebView
        return NO;
    }
    return YES;
}

/**
 *  Método responsável por executar as ações requisitadas pelo JavaScript. As ações devem ser conhecidas.
 *
 *  @param name            Nome da ação
 *  @param args            Argumentos que foram passados
 *  @param successCallback Nome da função para callback de sucesso
 *  @param errorCallback   Nome da função para callback de erro
 */
- (void)callNativeFunction:(NSString *)name withArgs:(NSArray *)args onSuccess:(NSString *)successCallback onError:(NSString *)errorCallback
{
    NSString *resultStr;
    
    // Identifica a função que deseja ser executada. As funções devem ser conhecidas previamente
    //
    if ([name compare:@"sayHello" options:NSCaseInsensitiveSearch] == NSOrderedSame)
    {
        // Esta função precisa de argumentos
        //
        if (args.count > 0) {
            resultStr = [NSString stringWithFormat:@"Hello %@ !", [args objectAtIndex:0]];
            [self callSuccessCallback:successCallback withRetValue:resultStr forFunction:name];
            
            // Escreve o argumento no label para visualização
            //
            self.label.text = [args objectAtIndex:0];
        }
        // Caso não tenha passado argumentos, retorna erro
        //
        else {
            resultStr = [NSString stringWithFormat:@"Erro na chamada da função %@. Erro: faltando parâmetros", name];
            [self callErrorCallback:errorCallback withMessage:resultStr];
            
            // Escreve o códifo de erro no label para visualização
            //
            self.label.text = @"Erro (-1)";
        }
    }
    // Função desconhecida
    //
    else {
        resultStr = [NSString stringWithFormat:@"Função não reconhecida: %@", name];
        [self callErrorCallback:errorCallback withMessage:resultStr];
        
        // Escreve o códifo de erro no label para visualização
        //
        self.label.text = @"Erro (-2)";
    }
}

/**
 *  Função responsável por montar a resposta para passar ao callback de erro
 *
 *  @param name Nome do callback de erro
 *  @param msg  Mensagem de erro que deve ser passada
 */
- (void)callErrorCallback:(NSString *)name withMessage:(NSString *)msg
{
    if (name != nil) {
        NSMutableDictionary *resultDict = [[NSMutableDictionary alloc] init];
        [resultDict setObject:msg forKey:@"error"];
        [self callJSFunction:name withArgs:resultDict];
    }
    else {
        NSLog(@"%@",msg);
    }
}

/**
 *  Função responsável por montar a resposta para passar ao callback de sucesso
 *
 *  @param name     Nome do callback de sucesso
 *  @param retValue Valor que deve ser retornado
 *  @param funcName Nome da função chamadora
 */
- (void)callSuccessCallback:(NSString *)name withRetValue:(id)retValue forFunction:(NSString *)funcName
{
    if (name != nil) {
        NSMutableDictionary *resultDict = [[NSMutableDictionary alloc] init];
        [resultDict setObject:retValue forKey:@"result"];
        [self callJSFunction:name withArgs:resultDict];
    }
    else {
        NSLog(@"Result of function %@ = %@", funcName, retValue);
    }
}

/**
 *  Método para executar funções JavaScript
 *
 *  @param name Nome da função
 *  @param args Argumentos
 */
- (void)callJSFunction:(NSString *)name withArgs:(NSMutableDictionary *)args
{
    NSError *jsonError;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:args options:0 error:&jsonError];
    
    if (jsonError != nil) {
        NSLog(@"Error creating JSON from the response  : %@",[jsonError localizedDescription]);
        return;
    }
    
    NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    NSLog(@"jsonStr = %@", jsonStr);
    
    if (jsonStr == nil) {
        NSLog(@"jsonStr is null. count = %d", [args count]);
    }
    
    [self.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@');",name,jsonStr]];
}

#pragma mark -
#pragma mark ViewController life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:nil]];
    
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    
    [self.webView loadRequest:req];
}

#pragma mark -
#pragma mark Target/Actions

/**
 *  Método para o botão de mudar a cor do documento Html atraves do JavaScript
 *
 *  @param sender Botão acionado
 */
- (IBAction)acionarFuncaoJS:(id)sender
{
    NSMutableDictionary *parametros = [[NSMutableDictionary alloc] init];
    [parametros setObject:self.cor.text forKey:@"cor"];
    
    [self callJSFunction:@"mudaCor" withArgs:parametros];
}

#pragma mark -
#pragma mark Delegates

/**
 *  Delegate do UIWebView responsável por definir se uma requisição será executada ou não
 *
 *  @param webView        WebView que acionou
 *  @param request        Requisição contendo a URL (ou o protocolo definido para execução do código nativo)
 *  @param navigationType Tipo da navegação
 *
 *  @return YES para executar a requisição, NO para não executar
 */
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL *url = [request URL];
    NSString *urlStr = url.absoluteString;
    
    return [self processURL:urlStr];
}

@end
