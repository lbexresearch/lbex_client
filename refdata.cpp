#include <string>
#include <iostream>
#include <fstream>
#include <map>

using namespace std;

int main()
{
 
    string instrument;
    string filename;
    int x;
    std::map <std::string,int> instrument2int;

    std::cout << "Hello" << std::endl;
    for( x=0; x < 10; x++)
    {
        std::cin >> instrument;
        instrument2int[instrument] = x;
    }

    std::map<std::string,int>::iterator it = instrument2int.begin();


    cout << "Reference data file :";
    cin >> filename;

    ifstream ifs;
    ifs.open("BATSSymbols-PROD.csv",std::ifstream::in); 
    for( it=instrument2int.begin();it!=instrument2int.end(); ++it) 
        std::cout << it->first << std::endl;
}
