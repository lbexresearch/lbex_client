#include <string>
#include <iostream>
#include <map>

using namespace std;

int main()
{
 
    std::string instrument;
    int x;
    std::map <std::string,int> instrument2int;

    std::cout << "Hello" << std::endl;
    for( x=0; x < 10; x++)
    {
        std::cin >> instrument;
        instrument2int[instrument] = x;
    }

    std::map<std::string,int>::iterator it = instrument2int.begin();


    cout << "Instrument Mapping :\n";
    for( it=instrument2int.begin();it!=instrument2int.end(); ++it) 
        std::cout << it->first << std::endl;
}
