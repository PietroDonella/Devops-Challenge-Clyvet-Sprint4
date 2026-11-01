using ClyvoVet.Api;

namespace ClyvoVet.UnitTests;

public class AppInfoTests
{
    [Fact]
    public void Titulo_DeveEstarPreenchido()
    {
        Assert.False(string.IsNullOrWhiteSpace(AppInfo.Titulo));
    }
}
