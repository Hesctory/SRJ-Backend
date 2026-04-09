using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class SecondLanguage
{
    public int EducationalPersonId { get; set; }

    public int SecondLanguageId { get; set; }

    public virtual EducationalPerson EducationalPerson { get; set; } = null!;

    public virtual Language SecondLanguageNavigation { get; set; } = null!;
}
