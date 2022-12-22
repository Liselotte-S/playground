import json
from collections import OrderedDict
import pprint

def main():
    initdict(3)
    print(janken1on1(1,1))
    return 0

def initdict(n):

    s = {"frag": True ,"Player1": {"name": "none", "hand": 0}}
    for i in range(1,n+1):
        update = {f'Player{i}':{"name": "none", "hand": 0}}
        s.update(update)
    with open('temp.json', 'w') as f:
        json.dump(s, f, indent=4)
    print(s)
    return s

def janken1on1(player,hand):
    with open('temp.json') as f:
        s = json.load(f)
    flags = s['frag']
    print(flags)
    a = 11
    b = 11
    if a == b:
        print('あいこで')
        return 99
        

    if a == 1 and b == 2:
        print('相手はチョキを出しました。あなたの勝ちです')
    elif a == 1 and b == 3:
        print('相手はパーを出しました。あなたの負けです')
    elif a == 2 and b == 1:
        print('相手はグーを出しました。あなたの負けです。')
    elif a == 2 and b == 3:
        print('相手はパーを出しました。あなたの勝ちです。')
    elif a == 3 and b == 1:
        print('相手はグーを出しました。あなたの勝ちです。')
    elif a == 3 and b == 2:
        print('相手はチョキを出しました。あなたの負けです。')
    else:
        print('1~3の数字を入力してください。')
    

def janken(n,a,b,c,d):
    aiko = f'{a}{b}{c}{d}'
    if ('1' and '2' and '3') in aiko or (a == b == c == d):
        return 99
    
    
    
    print(aiko)
    if a == b:
        print('あいこで')
    elif a == 1 and b == 2:
        print('相手はチョキを出しました。あなたの勝ちです')
    elif a == 1 and b == 3:
        print('相手はパーを出しました。あなたの負けです')
    elif a == 2 and b == 1:
        print('相手はグーを出しました。あなたの負けです。')
    elif a == 2 and b == 3:
        print('相手はパーを出しました。あなたの勝ちです。')
    elif a == 3 and b == 1:
        print('相手はグーを出しました。あなたの勝ちです。')
    elif a == 3 and b == 2:
        print('相手はチョキを出しました。あなたの負けです。')
    else:
        print('1~3の数字を入力してください。')


        
        
if __name__ == "__main__":
    main()